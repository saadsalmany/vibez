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
        << "lower_cutoff_freq = 25\n"
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
        << "integral = 65\n"
        << "gravity = 100\n"
        << "noise_reduction = 0.25\n";
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
    for (int i = 0; i < 64; ++i) {
        quint8 val = static_cast<quint8>(data[i]);
        rawVals[i] = static_cast<qreal>(val) / 255.0;
    }

    qreal bassSum = 0.0;
    qreal bassMax = 0.0;
    qreal midSum = 0.0;
    qreal trebSum = 0.0;

    for (int i = 0; i < 64; ++i) {
        qreal val = rawVals[i];
        // Authentic frequency response: instantaneous attack on transients, fluid natural decay
        if (val > m_bars[i]) {
            m_bars[i] = m_bars[i] * 0.15 + val * 0.85;
        } else {
            m_bars[i] = m_bars[i] * 0.78 + val * 0.22;
        }

        // Sub-bass & Bass: Bars 0-7 (25Hz - 180Hz)
        if (i < 8) {
            bassSum += m_bars[i];
            if (m_bars[i] > bassMax) {
                bassMax = m_bars[i];
            }
        } else if (i < 32) {
            // Mids & Vocals: Bars 8-31 (180Hz - 2800Hz)
            midSum += m_bars[i];
        } else {
            // Treble & High Sparkle: Bars 32-63 (2800Hz - 16000Hz)
            trebSum += m_bars[i];
        }
    }

    // Accurate representation of bass, mid, and treble levels
    m_bass = bassMax * 0.75 + (bassSum / 8.0) * 0.25;
    m_mid = midSum / 24.0;
    m_treble = trebSum / 32.0;

    // -------------------------------------------------------------
    // Authentic 808 Kick Drum & Beat Transient Detection
    // -------------------------------------------------------------
    qreal kickVal = 0.0;
    for (int i = 0; i < 6; ++i) {
        if (m_bars[i] > kickVal) {
            kickVal = m_bars[i];
        }
    }

    qreal kickRise = kickVal - m_prevKickEnergy;
    m_prevKickEnergy = kickVal;

    // Running baseline of low-end energy
    m_kickEnergyAvg = m_kickEnergyAvg * 0.95 + kickVal * 0.05;

    if (m_beatCooldown > 0) {
        m_beatCooldown--;
    }

    // Only fire on genuine percussive transients (sharp onset well above the rolling average)
    bool isKickSpike = (m_beatCooldown == 0) && (kickVal > 0.28) && (kickRise > 0.045) && (kickVal > m_kickEnergyAvg * 1.18);

    if (isKickSpike) {
        m_isBeatHit = true;
        m_beatCooldown = 6; // ~100ms cooldown for authentic drum hit spacing

        if (m_shakeEnabled) {
            qreal kickStrength = std::clamp((kickVal - 0.28) / 0.55, 0.0, 1.0);
            // Subtle, cinematic punch (up to 2.8% scale zoom, 4.5px vertical recoil)
            m_shakeScale = 1.0 + 0.028 * kickStrength;
            m_shakeY = 4.5 * kickStrength;
            m_shakeDir = !m_shakeDir;
            m_shakeX = (m_shakeDir ? 2.5 : -2.5) * kickStrength;
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
    if (m_shakeScale > 1.002) {
        m_shakeScale = m_shakeScale * 0.78 + 1.0 * 0.22; // Snappy elastic ease-out
    } else if (m_shakeScale != 1.0) {
        m_shakeScale = 1.0;
    }

    if (std::abs(m_shakeY) > 0.15) {
        m_shakeY *= 0.74; // Snappy recoil damping
    } else if (m_shakeY != 0.0) {
        m_shakeY = 0.0;
    }

    if (std::abs(m_shakeX) > 0.15) {
        m_shakeX *= 0.74;
    } else if (m_shakeX != 0.0) {
        m_shakeX = 0.0;
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
