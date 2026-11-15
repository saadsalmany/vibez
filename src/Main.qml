import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1280
    height: 720
    minimumWidth: 800
    minimumHeight: 500
    visible: true
    title: "Vibez - Audio Visualizer"
    color: "#08090D"

    Material.theme: Material.Dark
    Material.accent: theme.accent

    // Helper for rounded rectangles in QtQuick Context2D
    function drawRoundRect(ctx, x, y, w, h, r) {
        if (h <= 0 || w <= 0) return;
        r = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    }

    // Color themes
    readonly property var themes: [
        { name: "Cyberpunk", c1: "#00f5d4", c2: "#ff007f" },
        { name: "Trap Nation", c1: "#ffd166", c2: "#ef476f" },
        { name: "Emerald", c1: "#06d6a0", c2: "#118ab2" },
        { name: "Sunset", c1: "#9b5de5", c2: "#f15bb5" },
        { name: "Ice Blue", c1: "#00b4d8", c2: "#7209b7" }
    ]
    readonly property var curTheme: themes[backend.themeIndex % themes.length]

    // HUD visibility & Cinema Fullscreen mode
    property bool hudUserVisible: false

    Shortcut { sequence: "H"; onActivated: { hudUserVisible = !hudUserVisible; if (hudUserVisible) hudIdleTimer.restart(); } }
    Shortcut { sequence: "h"; onActivated: { hudUserVisible = !hudUserVisible; if (hudUserVisible) hudIdleTimer.restart(); } }

    // Keyboard Shortcuts
    Shortcut { sequence: "1"; onActivated: backend.setMode(0) }
    Shortcut { sequence: "2"; onActivated: backend.setMode(1) }
    Shortcut { sequence: "3"; onActivated: backend.setMode(2) }
    Shortcut { sequence: "4"; onActivated: backend.setMode(3) }
    Shortcut { sequence: "5"; onActivated: backend.setMode(4) }
    Shortcut { sequence: "6"; onActivated: backend.setMode(5) }
    Shortcut { sequence: "T"; onActivated: backend.nextTheme() }
    Shortcut { sequence: "t"; onActivated: backend.nextTheme() }
    Shortcut { sequence: "P"; onActivated: backend.toggleParticles() }
    Shortcut { sequence: "p"; onActivated: backend.toggleParticles() }
    Shortcut { sequence: "S"; onActivated: backend.toggleShake() }
    Shortcut { sequence: "s"; onActivated: backend.toggleShake() }
    Shortcut {
        sequence: "F"
        onActivated: window.visibility = (window.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }
    Shortcut {
        sequence: "f"
        onActivated: window.visibility = (window.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }
    Shortcut {
        sequence: "F11"
        onActivated: window.visibility = (window.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }
    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    Shortcut { sequence: "Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "q"; onActivated: Qt.quit() }

    // Mouse tracking, auto-hide timer & double-tap fullscreen
    Timer {
        id: hudIdleTimer
        interval: 2500
        running: false
        repeat: false
        onTriggered: {
            if (!hudHover.hovered) {
                hudUserVisible = false;
            }
        }
    }

    HoverHandler {
        id: globalMouseTracker
        cursorShape: (window.visibility === Window.FullScreen && !hud.showHud) ? Qt.BlankCursor : Qt.ArrowCursor
        onPointChanged: {
            // If cursor moves in bottom 140px, surface the HUD
            if (point.position.y > (window.height - 140)) {
                hudUserVisible = true;
                hudIdleTimer.restart();
            } else if (hudUserVisible) {
                // Cursor moving elsewhere while HUD is visible keeps it alive for 2.5s
                hudIdleTimer.restart();
            }
        }
    }

    TapHandler {
        onDoubleTapped: {
            window.visibility = (window.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen;
        }
    }

    // Root visualizer scene container with Bass Shake & Zoom Punch applied via GPU
    Item {
        id: shaker
        anchors.fill: parent
        scale: backend.shakeEnabled ? backend.shakeScale : 1.0
        transformOrigin: Item.Center
        transform: Translate {
            x: backend.shakeEnabled ? backend.shakeX : 0.0
            y: backend.shakeEnabled ? backend.shakeY : 0.0
        }

        // Visualizer Canvas (All visualizer drawing)
        Canvas {
            id: visCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            property real gridOffsetZ: 0
            property real singularityRot: 0

            Connections {
                target: backend
                function onAudioUpdated() {
                    visCanvas.gridOffsetZ = (visCanvas.gridOffsetZ + 3.5 + backend.bass * 8.0) % 40;
                    visCanvas.singularityRot += 0.008 + backend.bass * 0.02;
                    visCanvas.requestPaint();
                }
            }

            // Radial Particles System (Dynamic Swirling Beat-Reactive Stardust)
            property var particles: []
            property int maxParticles: 120
            property var trapAmps: null

            Component.onCompleted: {
                var cx = width > 0 ? width / 2 : 640;
                var cy = height > 0 ? height / 2 : 360;
                var maxR = Math.max(cx, cy) * 1.25;

                for (var i = 0; i < maxParticles; i++) {
                    particles.push({
                        angle: Math.random() * Math.PI * 2,
                        rad: 130 + Math.random() * maxR,
                        speed: Math.random() * 1.5 + 0.8,
                        spin: (Math.random() - 0.5) * 0.016,
                        size: Math.random() * 2.0 + 1.0,
                        alpha: Math.random() * 0.5 + 0.5
                    });
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2;
                var cy = height / 2;
                var bars = backend.bars;
                if (!bars || bars.length === 0) return;

                // -------------------------------------------------------------
                // 1. Swirling & Dancing Stardust Particles (Batched GPU Draw)
                // -------------------------------------------------------------
                if (backend.particlesEnabled) {
                    var maxDist = Math.max(width, height) * 0.85;
                    var bassFactor = backend.bass;
                    var speedMult = 1.0 + bassFactor * 4.2;
                    var beatKick = backend.isBeatHit ? (18.0 + bassFactor * 26.0) : 0;

                    ctx.beginPath();
                    for (var pIdx = 0; pIdx < particles.length; pIdx++) {
                        var p = particles[pIdx];
                        p.rad += p.speed * speedMult + beatKick;
                        p.angle += p.spin * (1.0 + bassFactor * 2.4);

                        if (p.rad > maxDist) {
                            p.rad = 130 + Math.random() * 50;
                            p.angle = Math.random() * Math.PI * 2;
                        }

                        var px = cx + Math.cos(p.angle) * p.rad;
                        var py = cy + Math.sin(p.angle) * p.rad;
                        var pSize = p.size * (1.0 + bassFactor * 0.45);

                        ctx.moveTo(px + pSize, py);
                        ctx.arc(px, py, pSize, 0, Math.PI * 2);
                    }
                    ctx.fillStyle = (backend.mode === 1) ? "#FFFFFF" : curTheme.c1;
                    ctx.globalAlpha = 0.38 + bassFactor * 0.32;
                    ctx.fill();
                }

                // ==============================================================
                // MODE 1: SALMANY NATION (Fluid Elastic Spring Physics & True Trap Dynamics)
                // ==============================================================
                if (backend.mode === 1) {
                    ctx.globalAlpha = 1.0; // Reset full opacity (essential for crisp solid rendering)
                    var minDim = Math.min(width, height);
                    // Responsive subwoofer disc radius: scales with screen, pulses subtly on heavy 808 kicks
                    var baseRadius = minDim * 0.22 * (1.0 + backend.bass * 0.06);
                    var baseOutline = Math.max(8.0, baseRadius * 0.10); // sleek circular ring during calm parts
                    var N = 96;
                    var halfN = N / 2;

                    // Initialize persistent elastic spring amplitudes
                    if (!visCanvas.trapAmps || visCanvas.trapAmps.length !== N) {
                        visCanvas.trapAmps = new Float32Array(N);
                    }
                    var tAmps = visCanvas.trapAmps;

                    // 1. Natural Organic Frequency Spectrum Sculpting (No Hardcoding)
                    // Sample the 64 real audio frequency bars symmetrically from top (12 o'clock) down to bottom (6 o'clock)
                    // Sub-bass & 808s flare the upper crests; mids/vocals sculpt the sides; treble ripples the base
                    var numBars = bars.length;
                    var bassEnergy = backend.bass;
                    var beatResonance = 1.0 + bassEnergy * 0.50; // Dynamic breathing excursion on heavy drops

                    for (var i = 0; i < N; i++) {
                        var symIdx = (i <= halfN) ? i : (N - i);
                        var t = symIdx / halfN; // 0.0 at top 12 o'clock, 1.0 at bottom 6 o'clock

                        // Logarithmic-frequency mapping across the 64 bars
                        // Concentrates bass & punch across the upper horns, with natural mid & treble spread
                        var bIdx = Math.pow(t, 0.78) * (numBars - 1);
                        var i0 = Math.floor(bIdx);
                        var i1 = Math.min(numBars - 1, i0 + 1);
                        var frac = bIdx - i0;
                        var rawFreq = (bars[i0] || 0.0) * (1.0 - frac) + (bars[i1] || 0.0) * frac;

                        // Frequency-dependent dynamic reach:
                        // Bass (t < 0.35) punches high with huge reach; mids (0.35 - 0.70) sculpt rich vocal/synth waves;
                        // Treble (0.70 - 1.0) sparkles with delicate crisp ripples
                        var freqWeight = 1.0;
                        if (t < 0.35) {
                            freqWeight = 1.25;
                        } else if (t < 0.70) {
                            freqWeight = 1.05;
                        } else {
                            freqWeight = 0.85;
                        }

                        // Dynamic excursion: clean power curve so silence/hum stays flat, real beats soar
                        var targetVal = Math.pow(rawFreq, 1.20) * freqWeight * beatResonance;

                        // Fast attack on beat hits (0.72) for instant transient response; snappy spring decay (0.82)
                        var cur = tAmps[i];
                        if (targetVal > cur) {
                            cur = cur * 0.28 + targetVal * 0.72;
                        } else {
                            cur = cur * 0.82;
                        }
                        tAmps[i] = cur;
                    }

                    // 2. Spatial 5-Point Gaussian Smoothing around perimeter for continuous liquid wave
                    var smoothed = new Float32Array(N);
                    for (var s = 0; s < N; s++) {
                        var p2 = (s - 2 + N) % N;
                        var p1 = (s - 1 + N) % N;
                        var n1 = (s + 1) % N;
                        var n2 = (s + 2 + N) % N;
                        smoothed[s] = tAmps[p2] * 0.08 + tAmps[p1] * 0.24 + tAmps[s] * 0.36 + tAmps[n1] * 0.24 + tAmps[n2] * 0.08;
                    }

                    // 3. Compute Radii with Natural Excursion:
                    var baseOutline = Math.max(8.0, baseRadius * 0.09);
                    var maxExcursion = baseRadius * 1.20;
                    var waveR = new Float32Array(N);
                    var waveSpread = new Float32Array(N);
                    var angles = new Float32Array(N);

                    for (var k = 0; k < N; k++) {
                        var angle = (k / N) * Math.PI * 2 - Math.PI / 2;
                        angles[k] = angle;

                        var amp = smoothed[k];
                        var excursion = amp * maxExcursion;
                        waveR[k] = baseRadius + baseOutline + excursion;

                        // Radiant Chromatic Flare: fans out with excursion and bass power
                        var flareRatio = Math.min(1.0, excursion / Math.max(1.0, maxExcursion * 0.8));
                        waveSpread[k] = 2.5 + flareRatio * (baseRadius * 0.45);
                    }

                    // Precalculate point coordinates for any layer factor
                    function buildLayerPts(factor) {
                        var pts = new Array(N);
                        for (var p = 0; p < N; p++) {
                            var rL = waveR[p] + waveSpread[p] * factor;
                            pts[p] = {
                                x: cx + Math.cos(angles[p]) * rL,
                                y: cy + Math.sin(angles[p]) * rL
                            };
                        }
                        return pts;
                    }

                    function traceSpline(pts) {
                        ctx.beginPath();
                        var pLast = pts[N - 1];
                        var p0 = pts[0];
                        ctx.moveTo((pLast.x + p0.x) * 0.5, (pLast.y + p0.y) * 0.5);
                        for (var j = 0; j < N; j++) {
                            var pCur = pts[j];
                            var pNxt = pts[(j + 1) % N];
                            ctx.quadraticCurveTo(pCur.x, pCur.y, (pCur.x + pNxt.x) * 0.5, (pCur.y + pNxt.y) * 0.5);
                        }
                        ctx.closePath();
                    }

                    var baseWavePts = buildLayerPts(0.0);

                    // 4. Stroke Giant Radiant Chromatic Layers (Electric Neon Behind the Horns)
                    var bassEnergy = backend.bass;

                    // Layer 5: Electric Cyan / Sky Blue Aura
                    traceSpline(buildLayerPts(1.0));
                    ctx.strokeStyle = "rgba(0, 240, 255, " + (0.50 + bassEnergy * 0.45) + ")";
                    ctx.lineWidth = Math.max(3.2, baseRadius * 0.035);
                    ctx.stroke();

                    // Layer 4: Neon Electric Green
                    traceSpline(buildLayerPts(0.78));
                    ctx.strokeStyle = "rgba(0, 255, 60, " + (0.65 + bassEnergy * 0.30) + ")";
                    ctx.lineWidth = Math.max(2.8, baseRadius * 0.030);
                    ctx.stroke();

                    // Layer 3: Vibrant Bright Yellow
                    traceSpline(buildLayerPts(0.55));
                    ctx.strokeStyle = "rgba(255, 235, 0, " + (0.80 + bassEnergy * 0.18) + ")";
                    ctx.lineWidth = Math.max(2.5, baseRadius * 0.026);
                    ctx.stroke();

                    // Layer 2: Warm Deep Orange
                    traceSpline(buildLayerPts(0.32));
                    ctx.strokeStyle = "rgba(255, 115, 0, " + (0.90 + bassEnergy * 0.10) + ")";
                    ctx.lineWidth = Math.max(2.3, baseRadius * 0.023);
                    ctx.stroke();

                    // Layer 1: Crimson Red
                    traceSpline(buildLayerPts(0.12));
                    ctx.strokeStyle = "rgba(255, 0, 45, 0.98)";
                    ctx.lineWidth = Math.max(2.0, baseRadius * 0.020);
                    ctx.stroke();

                    // 5. Solid Pure White Liquid Wave Body (Cleanly covers inner chromatic edges)
                    traceSpline(baseWavePts);
                    ctx.fillStyle = "#FFFFFF";
                    ctx.fill();

                    // 4. Central Subwoofer Disc with Custom "Salmany Nation" Emblem & City Skyline (Exactly matching Trap Nation)
                    ctx.save();
                    ctx.beginPath();
                    ctx.arc(cx, cy, baseRadius, 0, Math.PI * 2);
                    ctx.fillStyle = "#08090D"; // Solid pitch black central subwoofer disc
                    ctx.fill();
                    ctx.clip(); // Clip all contents inside the circular disc

                    // City Skyline Silhouette in crisp white at the bottom of the disc
                    ctx.fillStyle = "#FFFFFF";
                    var skyBaseY = cy + baseRadius * 0.98;
                    var blds = [
                        { dx: -0.42, w: 0.07, h: 0.24 },
                        { dx: -0.34, w: 0.08, h: 0.36 },
                        { dx: -0.25, w: 0.07, h: 0.48 },
                        { dx: -0.17, w: 0.06, h: 0.30 },
                        { dx: -0.10, w: 0.08, h: 0.58 }, // tall spire
                        { dx: -0.01, w: 0.07, h: 0.40 },
                        { dx:  0.07, w: 0.08, h: 0.52 },
                        { dx:  0.16, w: 0.07, h: 0.34 },
                        { dx:  0.24, w: 0.08, h: 0.46 },
                        { dx:  0.33, w: 0.08, h: 0.22 }
                    ];
                    for (var bi = 0; bi < blds.length; bi++) {
                        var bItem = blds[bi];
                        var bx = cx + bItem.dx * baseRadius * 2.0;
                        var bw = bItem.w * baseRadius * 2.0;
                        var bh = bItem.h * baseRadius;
                        ctx.fillRect(bx, skyBaseY - bh, bw, bh + 20);
                    }

                    // Stylized Typography: "Salmany Nation" in bold crisp white
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillStyle = "#FFFFFF";

                    // "Salmany" - bold italic stylized signature script
                    var sSize = Math.round(baseRadius * 0.38);
                    ctx.font = "italic 900 " + sSize + "px 'URW Gothic', 'Liberation Sans', 'Noto Sans', sans-serif";
                    ctx.fillText("Salmany", cx, cy - baseRadius * 0.18);

                    // Dynamic signature underline slash across Salmany in bold crisp white
                    ctx.beginPath();
                    ctx.lineWidth = Math.max(2.8, baseRadius * 0.038);
                    ctx.strokeStyle = "#FFFFFF";
                    ctx.moveTo(cx - baseRadius * 0.46, cy - baseRadius * 0.02);
                    ctx.lineTo(cx + baseRadius * 0.46, cy - baseRadius * 0.07);
                    ctx.stroke();

                    // "NATION" - bold uppercase geometric block typography with wide tracking
                    var nSize = Math.round(baseRadius * 0.22);
                    ctx.font = "900 " + nSize + "px 'URW Gothic', 'Liberation Sans', 'Nimbus Sans', sans-serif";
                    ctx.fillText("N  A  T  I  O  N", cx, cy + baseRadius * 0.16);

                    ctx.restore();
                }

                // ==============================================================
                // MODE 2: NEON TRAP CIRCLE (Dual-Color Gradient Spectrum)
                // ==============================================================
                else if (backend.mode === 2) {
                    var baseRadius2 = 115 + backend.bass * 38;
                    var totalBars2 = 64;
                    var halfBars2 = totalBars2 / 2;

                    // Expanding Bass Shockwaves
                    for (var s2 = shockwaves.length - 1; s2 >= 0; s2--) {
                        var sw2 = shockwaves[s2];
                        sw2.r += 6.5;
                        sw2.alpha -= 0.032;
                        if (sw2.alpha <= 0) {
                            shockwaves.splice(s2, 1);
                            continue;
                        }
                        ctx.strokeStyle = curTheme.c1;
                        ctx.globalAlpha = sw2.alpha * 0.7;
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.arc(cx, cy, sw2.r, 0, Math.PI * 2);
                        ctx.stroke();
                    }

                    ctx.lineWidth = 3.5;
                    ctx.lineCap = "round";

                    for (var i2 = 0; i2 < totalBars2; i2++) {
                        var angle2 = (i2 / totalBars2) * Math.PI * 2 - Math.PI / 2;
                        var barIdx2 = (i2 < halfBars2) ? Math.floor(i2 * (bars.length / halfBars2))
                                                      : Math.floor((totalBars2 - i2) * (bars.length / halfBars2));
                        barIdx2 = Math.max(0, Math.min(bars.length - 1, barIdx2));

                        var val2 = bars[barIdx2] || 0.0;
                        var barLen2 = val2 * 165 + 4;

                        var bx1 = cx + Math.cos(angle2) * baseRadius2;
                        var by1 = cy + Math.sin(angle2) * baseRadius2;
                        var bx2 = cx + Math.cos(angle2) * (baseRadius2 + barLen2);
                        var by2 = cy + Math.sin(angle2) * (baseRadius2 + barLen2);

                        var grad2 = ctx.createLinearGradient(bx1, by1, bx2, by2);
                        grad2.addColorStop(0, curTheme.c1);
                        grad2.addColorStop(1, curTheme.c2);

                        ctx.strokeStyle = grad2;
                        ctx.globalAlpha = 0.85 + val2 * 0.15;
                        ctx.beginPath();
                        ctx.moveTo(bx1, by1);
                        ctx.lineTo(bx2, by2);
                        ctx.stroke();
                    }

                    // Central Dark Circle
                    ctx.globalAlpha = 1.0;
                    ctx.fillStyle = "#0A0C13";
                    ctx.beginPath();
                    ctx.arc(cx, cy, baseRadius2, 0, Math.PI * 2);
                    ctx.fill();

                    // Central Ring Perimeter Glow
                    ctx.strokeStyle = curTheme.c1;
                    ctx.lineWidth = 3.5 + backend.bass * 2.5;
                    ctx.beginPath();
                    ctx.arc(cx, cy, baseRadius2, 0, Math.PI * 2);
                    ctx.stroke();

                    // Pulsing Bass Core Orb
                    var innerR2 = (baseRadius2 * 0.62) * (1.0 + backend.bass * 0.25);
                    var innerGrad2 = ctx.createRadialGradient(cx, cy, 0, cx, cy, innerR2);
                    innerGrad2.addColorStop(0, curTheme.c1);
                    innerGrad2.addColorStop(0.6, curTheme.c2);
                    innerGrad2.addColorStop(1, "transparent");
                    ctx.fillStyle = innerGrad2;
                    ctx.globalAlpha = 0.75 + backend.bass * 0.25;
                    ctx.beginPath();
                    ctx.arc(cx, cy, innerR2, 0, Math.PI * 2);
                    ctx.fill();

                    // Center Audio Glyph Bars
                    ctx.fillStyle = "#FFFFFF";
                    ctx.globalAlpha = 0.95;
                    var glyphBars2 = [0.35, 0.7, 1.0, 0.65, 0.4];
                    var gw2 = 4;
                    var ggap2 = 7;
                    var startGx2 = cx - (glyphBars2.length * (gw2 + ggap2)) / 2 + gw2 / 2;
                    for (var g2 = 0; g2 < glyphBars2.length; g2++) {
                        var gh2 = (glyphBars2[g2] * (26 + backend.bass * 28));
                        drawRoundRect(ctx, startGx2 + g2 * (gw2 + ggap2), cy - gh2 / 2, gw2, gh2, 2);
                        ctx.fill();
                    }
                }

                // ==============================================================
                // MODE 0: SPECTRUM BARS (Equalizer Studio VU Meter)
                // ==============================================================
                else if (backend.mode === 0) {
                    var totalBars = 64;
                    var margin = 60;
                    var availWidth = width - margin * 2;
                    var barWidth = (availWidth / totalBars) * 0.72;
                    var barGap = (availWidth / totalBars) * 0.28;
                    var maxBarHeight = height * 0.60;
                    var baseY = height - 120;

                    for (var b = 0; b < totalBars; b++) {
                        var val = bars[b] || 0.0;
                        var barH = val * maxBarHeight + 4;
                        var bx = margin + b * (barWidth + barGap);
                        var by = baseY - barH;

                        // Vertical Gradient Fill
                        var barGrad = ctx.createLinearGradient(bx, baseY, bx, by);
                        barGrad.addColorStop(0, curTheme.c1);
                        barGrad.addColorStop(0.65, curTheme.c2);
                        barGrad.addColorStop(1, "#FFFFFF");

                        ctx.fillStyle = barGrad;
                        ctx.globalAlpha = 0.85 + val * 0.15;
                        drawRoundRect(ctx, bx, by, barWidth, barH, barWidth / 2);
                        ctx.fill();

                        // Floor Reflection
                        var reflH = barH * 0.22;
                        var reflGrad = ctx.createLinearGradient(bx, baseY + 6, bx, baseY + 6 + reflH);
                        reflGrad.addColorStop(0, curTheme.c1);
                        reflGrad.addColorStop(1, "transparent");
                        ctx.fillStyle = reflGrad;
                        ctx.globalAlpha = 0.22;
                        drawRoundRect(ctx, bx, baseY + 6, barWidth, reflH, barWidth / 2);
                        ctx.fill();
                    }
                }

                // ==============================================================
                // MODE 3: LIQUID WAVE RIBBON
                // ==============================================================
                else if (backend.mode === 3) {
                    var waveGrad = ctx.createLinearGradient(0, cy, width, cy);
                    waveGrad.addColorStop(0, curTheme.c1);
                    waveGrad.addColorStop(0.5, curTheme.c2);
                    waveGrad.addColorStop(1, curTheme.c1);

                    ctx.strokeStyle = waveGrad;
                    ctx.lineWidth = 4.0 + backend.bass * 3.0;
                    ctx.globalAlpha = 0.9;
                    ctx.beginPath();

                    var step = width / (bars.length - 1);
                    ctx.moveTo(0, cy);

                    for (var w = 0; w < bars.length; w++) {
                        var normX = w * step;
                        var waveAmp = (bars[w] || 0.0) * (height * 0.35);
                        var waveY = cy - waveAmp * Math.sin((w / bars.length) * Math.PI);
                        ctx.lineTo(normX, waveY);
                    }
                    ctx.stroke();

                    // Mirrored Lower Wave Ribbon
                    ctx.lineWidth = 2.5;
                    ctx.globalAlpha = 0.42;
                    ctx.beginPath();
                    ctx.moveTo(0, cy);
                    for (var w2 = 0; w2 < bars.length; w2++) {
                        var normX2 = w2 * step;
                        var waveAmp2 = (bars[w2] || 0.0) * (height * 0.22);
                        var waveY2 = cy + waveAmp2 * Math.sin((w2 / bars.length) * Math.PI);
                        ctx.lineTo(normX2, waveY2);
                    }
                    ctx.stroke();
                }

                // ==============================================================
                // MODE 4: 3D CYBER GRID (Pure Synthwave Horizon & Perspective Grid)
                // ==============================================================
                else if (backend.mode === 4) {
                    var horizonY = height * 0.50;

                    // 1. Retro Synthwave Sun on Horizon (Clean sunset setting into the grid)
                    var sunRadius = 108 + backend.bass * 26;
                    var sunY = horizonY - sunRadius * 0.40;

                    ctx.save();
                    // Clip sun to sky only (above horizon)
                    ctx.beginPath();
                    ctx.rect(0, 0, width, horizonY);
                    ctx.clip();

                    ctx.beginPath();
                    ctx.arc(cx, sunY, sunRadius, 0, Math.PI * 2);
                    ctx.clip();

                    var sunGrad = ctx.createLinearGradient(cx, sunY - sunRadius, cx, sunY + sunRadius);
                    sunGrad.addColorStop(0, "#fde047");
                    sunGrad.addColorStop(0.35, "#fb923c");
                    sunGrad.addColorStop(0.68, "#ec4899");
                    sunGrad.addColorStop(1, "#9333ea");
                    ctx.fillStyle = sunGrad;
                    ctx.fillRect(cx - sunRadius, sunY - sunRadius, sunRadius * 2, sunRadius * 2);

                    // Horizontal Retro Blind Stripes
                    ctx.fillStyle = "#080614";
                    for (var s = 0; s < 9; s++) {
                        var sy = sunY + sunRadius * 0.04 + s * 10;
                        var sh = 2.4 + s * 1.0;
                        ctx.fillRect(cx - sunRadius, sy, sunRadius * 2, sh);
                    }
                    ctx.restore();

                    // 2. 3D Perspective Grid Floor (Solid dark base below horizon)
                    var floorGrad = ctx.createLinearGradient(cx, horizonY, cx, height);
                    floorGrad.addColorStop(0, "#080614");
                    floorGrad.addColorStop(0.25, "#04050a");
                    floorGrad.addColorStop(1, "#010204");
                    ctx.fillStyle = floorGrad;
                    ctx.fillRect(0, horizonY, width, height - horizonY);

                    // 3. Audio-Reactive Horizon Equalizer Wave (Dancing neon pulse on horizon)
                    ctx.save();
                    var horizGrad = ctx.createLinearGradient(0, horizonY, width, horizonY);
                    horizGrad.addColorStop(0, curTheme.c1);
                    horizGrad.addColorStop(0.5, curTheme.c2);
                    horizGrad.addColorStop(1, curTheme.c1);
                    ctx.strokeStyle = horizGrad;
                    ctx.lineWidth = 2.8 + backend.bass * 2.0;
                    ctx.globalAlpha = 0.90;

                    ctx.beginPath();
                    ctx.moveTo(0, horizonY);
                    var numHorizPts = bars.length;
                    var stepX = width / (numHorizPts * 2);
                    for (var hx = 0; hx <= numHorizPts * 2; hx++) {
                        var bIdx = (hx <= numHorizPts) ? (numHorizPts - hx) : (hx - numHorizPts);
                        bIdx = Math.min(bars.length - 1, Math.max(0, bIdx));
                        var barAmp = (bars[bIdx] || 0.0) * (42.0 + backend.bass * 36.0);
                        var px = hx * stepX;
                        // Subtly taper off wave amplitude near center so it doesn't obscure the sun
                        var distFromCenter = Math.abs(px - cx);
                        var sunMask = distFromCenter < (sunRadius * 0.75) ? (distFromCenter / (sunRadius * 0.75)) : 1.0;
                        var py = horizonY - barAmp * sunMask;
                        ctx.lineTo(px, py);
                    }
                    ctx.stroke();
                    ctx.restore();

                    // Glowing Solid Horizon Line
                    ctx.strokeStyle = curTheme.c1;
                    ctx.lineWidth = 2.2;
                    ctx.globalAlpha = 0.85;
                    ctx.beginPath();
                    ctx.moveTo(0, horizonY);
                    ctx.lineTo(width, horizonY);
                    ctx.stroke();

                    // 4. Floor Grid Perspective Lines
                    var fov = 350;
                    ctx.strokeStyle = curTheme.c1;
                    ctx.lineWidth = 1.4;
                    ctx.globalAlpha = 0.45;

                    // Longitudinal lines converging cleanly to horizon center (cx, horizonY)
                    for (var lx = -width * 1.5; lx <= width * 1.5; lx += 70) {
                        var xNear = cx + (lx * fov) / 50;
                        var xFar = cx + (lx * fov) / 800;
                        ctx.beginPath();
                        ctx.moveTo(xFar, horizonY);
                        ctx.lineTo(xNear, height);
                        ctx.stroke();
                    }

                    // Transverse lines scrolling towards camera
                    for (var lz = 50 - visCanvas.gridOffsetZ; lz <= 650; lz += 38) {
                        if (lz <= 20) continue;
                        var yProj = horizonY + (fov * 85) / lz;
                        if (yProj > height) continue;
                        ctx.beginPath();
                        ctx.moveTo(0, yProj);
                        ctx.lineTo(width, yProj);
                        ctx.stroke();
                    }
                }

                // ==============================================================
                // MODE 5: 3D SINGULARITY (Interstellar Black Hole & Accretion Disc)
                // ==============================================================
                else if (backend.mode === 5) {
                    var holeRadius = (85 + backend.bass * 25);
                    var tiltS = 0.40;
                    var points = 64;

                    // Accretion Disc
                    for (var pass = 0; pass < 2; pass++) {
                        ctx.beginPath();
                        for (var sp = 0; sp <= points; sp++) {
                            var spAngle = (sp / points) * Math.PI * 2 + visCanvas.singularityRot * (pass === 0 ? 1 : -1);
                            var spIdx = sp % (bars.length / 2);
                            var spVal = bars[spIdx] || 0.0;
                            var rDisc = holeRadius + 30 + spVal * 110 + (pass * 28);
                            var sx = cx + Math.cos(spAngle) * rDisc;
                            var sy = cy + Math.sin(spAngle) * rDisc * tiltS;

                            if (sp === 0) ctx.moveTo(sx, sy);
                            else ctx.lineTo(sx, sy);
                        }
                        ctx.strokeStyle = (pass === 0) ? curTheme.c1 : curTheme.c2;
                        ctx.lineWidth = 3.5;
                        ctx.globalAlpha = 0.85;
                        ctx.stroke();
                    }

                    // Void (Black Hole Event Horizon)
                    ctx.globalAlpha = 1.0;
                    ctx.fillStyle = "#020306";
                    ctx.beginPath();
                    ctx.arc(cx, cy, holeRadius, 0, Math.PI * 2);
                    ctx.fill();

                    // Photon Ring
                    ctx.strokeStyle = "#FFFFFF";
                    ctx.lineWidth = 3.0 + backend.bass * 2.0;
                    ctx.beginPath();
                    ctx.arc(cx, cy, holeRadius + 2, 0, Math.PI * 2);
                    ctx.stroke();

                    // Beat Flash
                    if (backend.isBeatHit) {
                        ctx.fillStyle = "#FFFFFF18";
                        ctx.beginPath();
                        ctx.arc(cx, cy, holeRadius * 1.5, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }
        }
    }

    // Floating Glass HUD (Auto-hides on idle for cinema-grade full screen)
    Rectangle {
        id: hud
        property bool showHud: hudUserVisible || hudHover.hovered
        anchors.bottom: parent.bottom
        anchors.bottomMargin: showHud ? 24 : -80
        anchors.horizontalCenter: parent.horizontalCenter
        height: 52
        width: contentRow.width + 32
        radius: 26
        color: "#161822EE"
        border.color: "#FFFFFF15"
        border.width: 1

        opacity: showHud ? 1.0 : 0.0
        visible: opacity > 0.01

        HoverHandler {
            id: hudHover
            onHoveredChanged: {
                if (hovered) {
                    hudUserVisible = true;
                    hudIdleTimer.stop();
                } else {
                    hudIdleTimer.restart();
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 10

            Button {
                text: "📊 Bars"
                flat: true
                highlighted: backend.mode === 0
                onClicked: backend.setMode(0)
            }
            Button {
                text: "🎯 Salmany Nation"
                flat: true
                highlighted: backend.mode === 1
                onClicked: backend.setMode(1)
            }
            Button {
                text: "🔥 Neon Circle"
                flat: true
                highlighted: backend.mode === 2
                onClicked: backend.setMode(2)
            }
            Button {
                text: "🌊 Wave"
                flat: true
                highlighted: backend.mode === 3
                onClicked: backend.setMode(3)
            }
            Button {
                text: "🕹️ Cyber Grid"
                flat: true
                highlighted: backend.mode === 4
                onClicked: backend.setMode(4)
            }
            Button {
                text: "🕳️ Singularity"
                flat: true
                highlighted: backend.mode === 5
                onClicked: backend.setMode(5)
            }

            Rectangle { width: 1; height: 24; color: "#FFFFFF20"; anchors.verticalCenter: parent.verticalCenter }

            Button {
                text: "🎨 " + curTheme.name
                flat: true
                onClicked: backend.nextTheme()
            }
            Button {
                text: backend.particlesEnabled ? "✨ Particles" : "🚫 Particles"
                flat: true
                highlighted: backend.particlesEnabled
                onClicked: backend.toggleParticles()
            }
            Button {
                text: backend.shakeEnabled ? "⚡ Shake" : "🚫 Shake"
                flat: true
                highlighted: backend.shakeEnabled
                onClicked: backend.toggleShake()
            }
        }
    }
}
