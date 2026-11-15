# Vibez — Real-Time Audio Spectrum Visualizer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Wayland%20%7C%20X11-purple.svg)]()
[![Framework](https://img.shields.io/badge/Built%20With-Qt%206%20%7C%20C%2B%2B17-41CD52.svg)]()
[![Performance](https://img.shields.io/badge/Performance-60%20FPS%20Lockstep%20VSync-orange.svg)]()
[![Author](https://img.shields.io/badge/Author-Saad%20Salmany-brightgreen.svg)](https://github.com/saadsalmany)

**Vibez** is a high-performance, hardware-accelerated audio visualizer crafted for Linux desktops by **Saad Salmany**. Built with modern **C++17** and **Qt 6 Quick / QML**, Vibez captures system audio in real-time via **PipeWire** / **PulseAudio** and renders fluid, beat-reactive visual spectrums at a rock-solid 60 FPS.

---

## Highlights & Features

- **Fluid Organic Wave Dynamics**: Dynamic multi-harmonic perimeter waves driven by real-time audio FFT frequencies.
- **Sub-3ms Render Latency**: Lockstep single-threaded scene graph render loop (`QSG_RENDER_LOOP=basic`), eliminating VSync stutter and frame drops under Wayland compositors (Hyprland, Sway, GNOME).
- **Zero-Allocation Animation Pipeline**: Precomputed trigonometric lookup tables and persistent typed memory buffers ensure zero garbage collector overhead during live rendering.
- **Beat-Reactive Transient Detection**: Dual-pass transient energy analysis detects heavy bass hits and 808 kicks, triggering reactive camera recoil, radial expansion, and stardust particle bursts.
- **Real-Time PipeWire / PulseAudio Capture**: Powered by an integrated Cava DSP audio engine with automatic gain control (AGC).
- **Multiple Visualization Modes**:
  1. **Salmany Nation**: Flagship circular audio visualizer with layered chromatic aura rings, fluid liquid wave body, central skyline silhouette, and custom typography.
  2. **Neon Spectrum Circle**: Symmetrical radial frequency spectrum with bass shockwaves.
  3. **Liquid Horizon Wave**: Mirrored dual-frequency fluid ribbon.
  4. **Cyber Grid**: 3D perspective synthesizer terrain with audio-reactive horizon wave.
  5. **Interstellar Singularity**: Orbital accretion disc and event horizon physics.
  6. **Frequency Bars**: Classic rounded vertical spectrum columns.
- **Auto-Hiding Glass HUD & Cinema Mode**: Modern floating control pill that tucks away automatically during inactivity.
- **Vim-Inspired Shortcuts**: Control the entire visualizer without leaving the keyboard.

---

## Keyboard Shortcuts

| Key | Action |
| :--- | :--- |
| `1` – `6` | Switch visualization modes |
| `T` / `t` | Cycle color themes (Cyberpunk, Trap Nation, Emerald, Sunset, Ice Blue) |
| `P` / `p` | Toggle floating stardust particle field |
| `S` / `s` | Toggle bass camera punch & zoom shake |
| `F` / `F11` | Toggle Cinema Fullscreen mode |
| `H` / `h` | Show / Hide floating glass HUD |
| `Q` / `Esc` | Quit Vibez |

---

## Installation & Build Guide

### Prerequisites (Arch Linux / Omarchy)

```bash
sudo pacman -S qt6-base qt6-declarative qt6-quickcontrols2 cava gcc make
```

### Building from Source

```bash
git clone https://github.com/saadsalmany/vibez.git
cd vibez

# Run build script
./bin/build

# Or build manually using qmake6
mkdir -p build && cd build
qmake6 ../vibez.pro
make -j$(nproc)

# Install binary to local path
install -m 755 vibez ~/.local/bin/vibez
```

### Dependencies (Debian / Ubuntu)

```bash
sudo apt install qt6-base-dev qt6-declarative-dev qml6-module-qtquick-controls cava g++ make
```

### Dependencies (Fedora)

```bash
sudo dnf install qt6-qtbase-devel qt6-qtdeclarative-devel cava gcc-c++ make
```

---

## Engineering & Architecture

Vibez was designed from the ground up to solve the micro-stutter and high resource consumption issues common in browser-based and Electron audio visualizers:

1. **Wayland Fullscreen Synchronization**:
   Standard threaded render loops often suffer from frame-phase collision when Wayland compositors force `eglSwapBuffers` to block waiting for monitor VBLANK. Vibez configures Qt's lockstep render loop to execute animation updates, OpenGL FBO drawing, and buffer swapping sequentially on a single thread. Total frame preparation completes in 3–4 ms, providing more than 12 ms of headroom before the 16.67 ms display deadline.

2. **Zero-Allocation GPU Splines**:
   Perimeter spline interpolation is traced through a closed quadratic curve loop using precomputed cosine and sine lookup tables (`cosTable`, `sinTable`). Memory allocations are eliminated on the rendering path to prevent JavaScript engine heap churn.

3. **Dynamic Audio AGC**:
   The audio DSP pipeline dynamically normalizes rolling audio peaks, ensuring delicate acoustic passages stay detailed while drop sections hit with maximum punch.

---

## Author & Brand Identity

**Vibez** is designed and maintained by **Saad Salmany**.

- **GitHub**: [@saadsalmany](https://github.com/saadsalmany)
- **Portfolio & Projects**: [Saad Salmany Profile](https://github.com/saadsalmany)
- **Contact**: saadsalmanyy@gmail.com

If you find this project useful or build upon it, feel free to give it a star!

---

## License

This project is licensed under the [MIT License](LICENSE) &copy; 2026 Saad Salmany.
