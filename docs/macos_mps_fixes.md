# MPS Compatibility Fixes for macOS

This document describes the fixes applied to make Lada compatible with Apple's Metal Performance Shaders (MPS) on macOS.

## Issue Description

When running Lada with `--device mps` on macOS, users encountered a `ValueError: invalid type: 'torch.mps.FloatTensor'` error. This was caused by incompatible tensor type conversions in the codebase that didn't account for MPS tensor types.

## Fixes Applied

### 1. flow_warp.py (BasicVSR++ module)

**File**: `lada/basicvsrpp/mmagic/flow_warp.py`

**Issue**: Line 52 used `grid_flow.type(x.type())` which doesn't work with MPS tensors.

**Fix**: Changed to `grid_flow.to(dtype=x.dtype)` which is compatible with all device types including MPS.

```python
# Before
grid_flow = grid_flow.type(x.type())

# After
grid_flow = grid_flow.to(dtype=x.dtype)
```

### 3. MPS Padding Mode Compatibility (flow_warp.py)

**File**: `lada/basicvsrpp/mmagic/flow_warp.py`

**Issue**: MPS doesn't support "zeros" padding mode in grid_sample operations, causing `RuntimeError: MPS: Unsupported Border padding mode`.

**Fix**: Added automatic fallback to "reflection" padding mode when using MPS (MPS only supports "reflection" padding mode):

```python
def flow_warp(
    x, flow, interpolation="bilinear", padding_mode="zeros", align_corners=True
):
    # Fix for MPS compatibility - MPS only supports 'reflection' padding mode
    if x.is_mps and padding_mode in ["zeros", "border"]:
        padding_mode = "reflection"
```

### 4. MPS Empty Tensor Error Handling (flow_warp.py)

**File**: `lada/basicvsrpp/mmagic/flow_warp.py`

**Issue**: MPS sometimes throws "Placeholder tensor is empty" error during grid_sample operations, particularly with certain video resolutions or tensor shapes.

**Fix**: Added comprehensive error handling with CPU fallback:

1. Added tensor validation to check for empty tensors and invalid dimensions
2. Added NaN/Inf value detection and clamping for grid values
3. Implemented try-catch with CPU fallback when MPS grid_sample fails
4. Added extensive debug logging to diagnose MPS issues

```python
# Try grid_sample with MPS, fallback to CPU if it fails
try:
    output = F.grid_sample(
        x,
        grid_flow,
        mode=interpolation,
        padding_mode=padding_mode,
        align_corners=align_corners,
    )
except RuntimeError as e:
    if x.is_mps and "Placeholder tensor is empty" in str(e):
        print(f"[WARNING] MPS grid_sample failed with error: {e}")
        print("[INFO] Falling back to CPU for flow_warp operation")

        # Move tensors to CPU and retry
        x_cpu = x.cpu()
        grid_flow_cpu = grid_flow.cpu()

        output = F.grid_sample(
            x_cpu,
            grid_flow_cpu,
            mode=interpolation,
            padding_mode=padding_mode,
            align_corners=align_corners,
        )

        # Move result back to MPS device
        output = output.to(x.device)
    else:
        # Re-raise the exception if it's not the MPS empty tensor error
        raise
```

### 5. Single Frame Processing Fix (basicvsr_plusplus_net.py)

**File**: `lada/basicvsrpp/mmagic/basicvsr_plusplus_net.py`

**Issue**: When processing single frames or clips with only one frame, the optical flow computation fails because it requires at least two frames to compute flow between them. This results in empty tensors with shape [0, 3, 64, 64] being passed to the flow computation functions.

**Fix**: Added special handling for single frame cases:

1. In `compute_flow()` method: Check if frame count <= 1 and return zero flows
2. In `propagate()` method: Check if flow tensor has zero time dimension and skip propagation

```python
# Handle single frame case - no flow can be computed
if t <= 1:
    # Return zero flows for single frame
    device = lqs.device
    dtype = lqs.dtype
    flows_forward = torch.zeros(n, 0, 2, h, w, device=device, dtype=dtype)
    flows_backward = torch.zeros(n, 0, 2, h, w, device=device, dtype=dtype)
    return flows_forward, flows_backward
```

```python
# Handle case with no flows (single frame)
if t == 0:
    # Just copy spatial features without propagation
    for feat in feats["spatial"]:
        feats[module_name].append(feat.clone())
    return feats
```

### 2. model_util.py (DeepMosaics module)

**File**: `lada/deepmosaics/models/model_util.py`

**Issue**: Line 457 used `self.window.data.type() == img1.data.type()` which doesn't work with MPS tensors.

**Fix**: Changed to `self.window.data.dtype == img1.data.dtype` which compares the dtype directly.

```python
# Before
if channel == self.channel and self.window.data.type() == img1.data.type():

# After
if channel == self.channel and self.window.data.dtype == img1.data.dtype:
```

## Impact

These fixes ensure that:

1. BasicVSR++ model works correctly with MPS device
2. DeepMosaics model works correctly (though it still falls back to CPU as it doesn't fully support MPS)
3. All tensor type conversions are device-agnostic

## Testing

After applying these fixes, users can now run Lada with MPS acceleration:

```bash
lada-cli --input video.mp4 --device mps
```

The compatibility test script can verify the fixes:

```bash
python scripts/test_mps_compatibility.py
```

## Future Considerations

1. The DeepMosaics model still requires CPU for some operations even with MPS selected
2. Future PyTorch versions may improve MPS compatibility further
3. Consider adding more comprehensive MPS error handling for edge cases
