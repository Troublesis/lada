## Developer Installation (macOS)

This section describes how to install the app (CLI and GUI) on macOS, specifically optimized for Apple Silicon (M1/M2/M3/M4) chips.

> [!NOTE]
> This is the macOS guide. For Linux installation see [Linux Installation](linux_install.md).
> For Windows installation see [Windows Installation](windows_install.md).

### System Requirements

- macOS 13.0 (Ventura) or higher
- Apple Silicon chip (M1/M2/M3/M4) recommended for best performance
- Python 3.12 or 3.13
- Xcode Command Line Tools

### Install CLI

1. Install Homebrew (if not already installed):

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Get the code

   ```bash
   git clone https://github.com/ladaapp/lada.git
   cd lada
   ```

3. Install system dependencies

   ```bash
   brew install python@3.13 ffmpeg
   ```

4. Create a virtual environment to install python dependencies

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```

5. Install PyTorch with MPS (Metal Performance Shaders) support for Apple Silicon

   ```bash
   pip install torch torchvision torchaudio
   ```

   > [!TIP]
   > The above command will automatically install the optimized version of PyTorch for Apple Silicon which includes MPS support.

6. Verify PyTorch installation with MPS support

   ```bash
   python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'MPS available: {torch.backends.mps.is_available()}'); print(f'MPS built: {torch.backends.mps.is_built()}')"
   ```

   If `MPS available` shows `True`, your installation is correctly configured for Apple Silicon GPU acceleration.

7. Install python dependencies

   ```bash
   python -m pip install -e '.[basicvsrpp]'
   ```

8. Apply patches

   On low-end hardware running mosaic detection model could run into a timeout defined in ultralytics library and the scene would not be restored. The following patch increases this time limit:

   ```bash
   patch -u .venv/lib/python3.1[23]/site-packages/ultralytics/utils/nms.py patches/increase_mms_time_limit.patch
   ```

   Disable crash-reporting / telemetry of one of our dependencies (ultralytics):

   ```bash
   patch -u .venv/lib/python3.1[23]/site-packages/ultralytics/utils/__init__.py  patches/remove_ultralytics_telemetry.patch
   ```

   Compatibility fix for using mmengine (restoration model dependency) with latest PyTorch:

   ```bash
   patch -u .venv/lib/python3.1[23]/site-packages/mmengine/runner/checkpoint.py  patches/fix_loading_mmengine_weights_on_torch26_and_higher.diff
   ```

9. Download model weights

   Download the models from the GitHub Releases page into the `model_weights` directory. The following commands do just that

   ```shell
   wget -P model_weights/ 'https://github.com/ladaapp/lada/releases/download/v0.7.1/lada_mosaic_detection_model_v3.1_accurate.pt'
   wget -P model_weights/ 'https://github.com/ladaapp/lada/releases/download/v0.7.1/lada_mosaic_detection_model_v3.1_fast.pt'
   wget -P model_weights/ 'https://github.com/ladaapp/lada/releases/download/v0.2.0/lada_mosaic_detection_model_v2.pt'
   wget -P model_weights/ 'https://github.com/ladaapp/lada/releases/download/v0.6.0/lada_mosaic_restoration_model_generic_v1.2.pth'
   ```

   If you're interested in running DeepMosaics' restoration model you can also download their pretrained model `clean_youknow_video.pth`

   ```shell
   wget -O model_weights/3rd_party/clean_youknow_video.pth 'https://drive.usercontent.google.com/download?id=1ulct4RhRxQp1v5xwEmUH7xz7AK42Oqlw&export=download&confirm=t'
   ```

Now you should be able to run the CLI by calling `lada-cli`. For optimal performance on Apple Silicon, use the MPS device:

```bash
lada-cli --input <input video path> --device mps
```

### Install GUI

1. Install everything mentioned in [Install CLI](#install-cli)

2. Install additional system dependencies for GUI

   ```bash
   brew install gtk4 gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav adwaita-icon-theme
   ```

3. Install python dependencies
   ```bash
   python -m pip install -e '.[gui]'
   ```

> [!TIP]
> If you intend to hack on the GUI code install also `gui-dev` extra: `python -m pip install -e '.[gui-dev]'`

Now you should be able to run the GUI by calling `lada`.

### Performance Optimization for M4 Chip

For optimal performance on macOS Studio M4 chip:

1. Use the MPS device for GPU acceleration:

   ```bash
   lada-cli --input <input video path> --device mps
   ```

2. In the GUI, select "MPS" as the device in the configuration sidebar.

3. For 4K videos, consider reducing the max clip length to manage memory:

   ```bash
   lada-cli --input <input video path> --device mps --max-clip-length 120
   ```

4. Use hardware-accelerated video encoding with the Apple VideoToolbox:
   ```bash
   lada-cli --input <input video path> --device mps --codec h264_videotoolbox
   ```

### Troubleshooting

#### MPS not available

If you see "MPS available: False" when checking PyTorch installation:

1. Ensure you're running macOS 13.0 (Ventura) or higher
2. Make sure you're using an Apple Silicon Mac
3. Update PyTorch to the latest version:
   ```bash
   pip install --upgrade torch torchvision torchaudio
   ```

#### GTK theme issues

If the GUI doesn't look right:

1. Install the Adwaita theme:

   ```bash
   brew install adwaita-icon-theme
   ```

2. Set the GTK theme:
   ```bash
   export GTK_THEME=Adwaita:dark
   lada
   ```

#### Memory issues with large videos

If you encounter memory errors with large videos:

1. Reduce the max clip length:

   ```bash
   lada-cli --input <input video path> --device mps --max-clip-length 60
   ```

2. Process the video in smaller chunks if possible.
