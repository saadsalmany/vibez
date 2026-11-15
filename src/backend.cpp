#include "backend.h"
#include <QTextStream>
#include <QRandomGenerator>
#include <cmath>

Backend::Backend(QObject *parent) : QObject(parent) {
    m_bars.resize(64);
    for (int i = 0; i < 64; ++i) {
        m_bars[i] = 0.0;
    }

    startCava();

    connect(&m_decayTimer, &QTimer::timeout, this, &Backend::onDecayTick);
    m_decayTimer.start(16); // 60 FPS decay loop
}

Backend::~Backend() {
    if (m_cavaProcess.state() != QProcess::NotRunning) {
        m_cavaProcess.kill();
        m_cavaProcess.waitForFinished(1000);
    }
}

void Backend::startCava() {
    if (!m_configFile.open()) {
        return;
    }

    QTextStream out(&m_configFile);
    out << "[general]\n"
        << "framerate = 60\n"
        << "autosens = 1\n"
        << "bars = 64\n"
        << "lower_cutoff_freq = 40\n"
        << "higher_cutoff_freq = 16000\n\n"
        << "[input]\n"
        << "method = pipewire\n"
        << "source = auto\n\n"
        << "[output]\n"
        << "method = raw\n"
        << "raw_target = /dev/stdout\n"
        << "data_format = binary\n"
        << "bit_format = 8bit\n"
        << "channels = mono\n\n"
        << "[smoothing]\n"
        << "monstercat = 0\n"
        << "integral = 15\n"
        << "gravity = 65\n"
        << "noise_reduction = 0.10\n";
    m_configFile.flush();

    connect(&m_cavaProcess, &QProcess::readyReadStandardOutput, this, &Backend::onCavaOutput);
    m_cavaProcess.start("cava", QStringList() << "-p" << m_configFile.fileName());
}

void Backend::onCavaOutput() {
    m_readBuffer.append(m_cavaProcess.readAllStandardOutput());

    // Only process the latest frame of 64 bytes to eliminate any buffering latency
    if (m_readBuffer.size() < 64) {
        return;
    }

    // Skip to the most recent 64-byte chunk
    int excess = m_readBuffer.size() % 64;
    int latestStart = m_readBuffer.size() - excess - 64;
    const char *data = m_readBuffer.constData() + latestStart;

    qreal rawVals[64];
    qreal rawFramePeak = 0.0;
    for (int i = 0; i < 64; ++i) {
        quint8 val = static_cast<quint8>(data[i]);
        qreal norm = static_cast<qreal>(val) / 255.0;
        rawVals[i] = norm;
        if (norm > rawFramePeak) {
            rawFramePeak = norm;
        }
    }

    // Dynamic Automatic Gain Control (AGC):
    // Fast attack captures peak loudness of the track, slow decay preserves dynamic range
    // so quiet verses stay calm and drops hit with explosive contrast
    if (rawFramePeak > m_rollingPeak) {
        m_rollingPeak = m_rollingPeak * 0.85 + rawFramePeak * 0.15;
    } else {
        m_rollingPeak = m_rollingPeak * 0.9985;
    }
    m_rollingPeak = std::clamp(m_rollingPeak, 0.22, 1.0);
    qreal autoGain = 1.0 / m_rollingPeak;

    qreal bassSum = 0.0;
    qreal bassMax = 0.0;
    qreal midSum = 0.0;
    qreal trebSum = 0.0;

    for (int i = 0; i < 64; ++i) {
        qreal boosted = std::min(1.0, rawVals[i] * autoGain);
        m_bars[i] = boosted;

        // Sub-bass & Bass: Bars 0-14 (40Hz - 450Hz)
        if (i < 15) {
            bassSum += boosted;
            if (boosted > bassMax) {
                bassMax = boosted;
            }
        } else if (i < 36) {
            // Mids & Vocals: Bars 15-35 (450Hz - 3200Hz)
            midSum += boosted;
        } else {
            // Treble & High Sparkle: Bars 36-63 (3200Hz - 16000Hz)
            trebSum += boosted;
        }
    }

    // Blend peak transients (for instant 808 kick response) and body energy
    m_bass = bassMax * 0.65 + (bassSum / 15.0) * 0.35;
    m_mid = midSum / 21.0;
    m_treble = trebSum / 28.0;

    // -------------------------------------------------------------
    // Precise 808 Kick Drum & Drop Beat Detection
    // -------------------------------------------------------------
    // Sub-bass & Bass kick drum is in bars 0 to 8 (~40Hz - 200Hz)
    qreal kickVal = 0.0;
    for (int i = 0; i <= 8; ++i) {
        if (m_bars[i] > kickVal) {
            kickVal = m_bars[i];
        }
    }
    kickVal = std::max(kickVal, m_bass);

    qreal kickRise = kickVal - m_prevKickEnergy;
    m_prevKickEnergy = kickVal;

    // Moving average of kick energy for dynamic contrast
    m_kickEnergyAvg = m_kickEnergyAvg * 0.94 + kickVal * 0.06;

    if (m_beatCooldown > 0) {
        m_beatCooldown--;
    }

    // High-impact percussive kick detection:
    // Triggers on sharp transient onset above floor (0.22)
    // AND stays sensitive during heavy drops (kickVal > 0.45)
    bool isKickSpike = (m_beatCooldown == 0) && (kickVal > 0.22) &&
        ((kickRise > 0.022 && kickVal > m_kickEnergyAvg * 1.06) || (kickVal > 0.45 && kickRise > 0.012));

    if (isKickSpike) {
        m_isBeatHit = true;
        m_beatCooldown = 3; // ~50ms cooldown for fast trap/EDM beats

        if (m_shakeEnabled) {
            qreal kickStrength = std::clamp((kickVal - 0.20) / 0.65, 0.0, 1.0);
            // Heavy Bass Camera Zoom Punch (up to 1.09x scale expansion)
            m_shakeScale = 1.0 + 0.088 * kickStrength;
            // Visible cinematic vertical recoil (up to 15px)
            m_shakeY = 15.0 * kickStrength;
            // Alternating horizontal kick punch (up to 9px)
            m_shakeDir = !m_shakeDir;
            m_shakeX = (m_shakeDir ? 9.0 : -9.0) * kickStrength;
        }
    } else {
        m_isBeatHit = false;
    }

    // Keep buffer tight to avoid unbounded memory growth
    if (excess > 0) {
        m_readBuffer = m_readBuffer.right(excess);
    } else {
        m_readBuffer.clear();
    }

    emit audioUpdated();
}

void Backend::onDecayTick() {
    bool changed = false;

    if (m_shakeScale > 1.002) {
        m_shakeScale = m_shakeScale * 0.78 + 1.0 * 0.22; // Snappy elastic ease-out
        changed = true;
    } else if (m_shakeScale != 1.0) {
        m_shakeScale = 1.0;
        changed = true;
    }

    if (std::abs(m_shakeY) > 0.15) {
        m_shakeY *= 0.74; // Snappy recoil damping
        changed = true;
    } else if (m_shakeY != 0.0) {
        m_shakeY = 0.0;
        changed = true;
    }

    if (std::abs(m_shakeX) > 0.15) {
        m_shakeX *= 0.74;
        changed = true;
    } else if (m_shakeX != 0.0) {
        m_shakeX = 0.0;
        changed = true;
    }

    if (changed) {
        emit audioUpdated();
    }
}

void Backend::setMode(int m) {
    if (m_mode != m) {
        m_mode = (m % 6 + 6) % 6;
        emit modeChanged();
    }
}

void Backend::nextMode() {
    setMode(m_mode + 1);
}

void Backend::setThemeIndex(int t) {
    if (m_themeIndex != t) {
        m_themeIndex = (t % 5 + 5) % 5;
        emit themeChanged();
    }
}

void Backend::nextTheme() {
    setThemeIndex(m_themeIndex + 1);
}

void Backend::setParticlesEnabled(bool enabled) {
    if (m_particlesEnabled != enabled) {
        m_particlesEnabled = enabled;
        emit particlesChanged();
    }
}

void Backend::toggleParticles() {
    setParticlesEnabled(!m_particlesEnabled);
}

void Backend::setShakeEnabled(bool enabled) {
    if (m_shakeEnabled != enabled) {
        m_shakeEnabled = enabled;
        if (!m_shakeEnabled) {
            m_shakeScale = 1.0;
            m_shakeX = 0.0;
            m_shakeY = 0.0;
        }
        emit shakeChanged();
        emit audioUpdated();
    }
}

void Backend::toggleShake() {
    setShakeEnabled(!m_shakeEnabled);
}
