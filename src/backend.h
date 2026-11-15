#pragma once

#include <QObject>
#include <QList>
#include <QProcess>
#include <QTimer>
#include <QTemporaryFile>
#include <QSettings>

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QList<qreal> bars READ bars NOTIFY audioUpdated)
    Q_PROPERTY(qreal bass READ bass NOTIFY audioUpdated)
    Q_PROPERTY(qreal mid READ mid NOTIFY audioUpdated)
    Q_PROPERTY(qreal treble READ treble NOTIFY audioUpdated)
    Q_PROPERTY(qreal shakeScale READ shakeScale NOTIFY audioUpdated)
    Q_PROPERTY(qreal shakeX READ shakeX NOTIFY audioUpdated)
    Q_PROPERTY(qreal shakeY READ shakeY NOTIFY audioUpdated)
    Q_PROPERTY(bool isBeatHit READ isBeatHit NOTIFY audioUpdated)
    Q_PROPERTY(int mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(int themeIndex READ themeIndex WRITE setThemeIndex NOTIFY themeChanged)
    Q_PROPERTY(int bgIndex READ bgIndex WRITE setBgIndex NOTIFY bgIndexChanged)
    Q_PROPERTY(bool particlesEnabled READ particlesEnabled WRITE setParticlesEnabled NOTIFY particlesChanged)
    Q_PROPERTY(bool shakeEnabled READ shakeEnabled WRITE setShakeEnabled NOTIFY shakeChanged)

    // Avee Player Live Customization Properties
    Q_PROPERTY(QString customBgImage READ customBgImage WRITE setCustomBgImage NOTIFY customBgImageChanged)
    Q_PROPERTY(qreal bgDim READ bgDim WRITE setBgDim NOTIFY bgDimChanged)
    Q_PROPERTY(int particleCount READ particleCount WRITE setParticleCount NOTIFY particleCountChanged)
    Q_PROPERTY(qreal particleSpeed READ particleSpeed WRITE setParticleSpeed NOTIFY particleSpeedChanged)
    Q_PROPERTY(qreal twinkleRatio READ twinkleRatio WRITE setTwinkleRatio NOTIFY twinkleRatioChanged)
    Q_PROPERTY(qreal bassSensitivity READ bassSensitivity WRITE setBassSensitivity NOTIFY bassSensitivityChanged)
    Q_PROPERTY(qreal beatPunch READ beatPunch WRITE setBeatPunch NOTIFY beatPunchChanged)
    Q_PROPERTY(qreal discPulse READ discPulse WRITE setDiscPulse NOTIFY discPulseChanged)

public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    QList<qreal> bars() const { return m_bars; }
    qreal bass() const { return m_bass; }
    qreal mid() const { return m_mid; }
    qreal treble() const { return m_treble; }
    qreal shakeScale() const { return m_shakeScale; }
    qreal shakeX() const { return m_shakeX; }
    qreal shakeY() const { return m_shakeY; }
    bool isBeatHit() const { return m_isBeatHit; }

    int mode() const { return m_mode; }
    Q_INVOKABLE void setMode(int m);

    int themeIndex() const { return m_themeIndex; }
    Q_INVOKABLE void setThemeIndex(int t);

    int bgIndex() const { return m_bgIndex; }
    Q_INVOKABLE void setBgIndex(int b);

    bool particlesEnabled() const { return m_particlesEnabled; }
    Q_INVOKABLE void setParticlesEnabled(bool enabled);

    bool shakeEnabled() const { return m_shakeEnabled; }
    Q_INVOKABLE void setShakeEnabled(bool enabled);

    // Avee Customizer Getters & Setters
    QString customBgImage() const { return m_customBgImage; }
    Q_INVOKABLE void setCustomBgImage(const QString &path);

    qreal bgDim() const { return m_bgDim; }
    Q_INVOKABLE void setBgDim(qreal dim);

    int particleCount() const { return m_particleCount; }
    Q_INVOKABLE void setParticleCount(int count);

    qreal particleSpeed() const { return m_particleSpeed; }
    Q_INVOKABLE void setParticleSpeed(qreal speed);

    qreal twinkleRatio() const { return m_twinkleRatio; }
    Q_INVOKABLE void setTwinkleRatio(qreal ratio);

    qreal bassSensitivity() const { return m_bassSensitivity; }
    Q_INVOKABLE void setBassSensitivity(qreal sens);

    qreal beatPunch() const { return m_beatPunch; }
    Q_INVOKABLE void setBeatPunch(qreal punch);

    qreal discPulse() const { return m_discPulse; }
    Q_INVOKABLE void setDiscPulse(qreal pulse);

    Q_INVOKABLE void nextMode();
    Q_INVOKABLE void nextTheme();
    Q_INVOKABLE void nextBackground();
    Q_INVOKABLE void toggleParticles();
    Q_INVOKABLE void toggleShake();
    Q_INVOKABLE void resetToDefaults();

signals:
    void audioUpdated();
    void modeChanged();
    void themeChanged();
    void bgIndexChanged();
    void particlesChanged();
    void shakeChanged();
    void customBgImageChanged();
    void bgDimChanged();
    void particleCountChanged();
    void particleSpeedChanged();
    void twinkleRatioChanged();
    void bassSensitivityChanged();
    void beatPunchChanged();
    void discPulseChanged();

private slots:
    void onCavaOutput();
    void onDecayTick();

private:
    void startCava();
    void loadSettings();
    void saveSetting(const QString &key, const QVariant &value);

    QProcess m_cavaProcess;
    QTemporaryFile m_configFile;
    QByteArray m_readBuffer;

    QList<qreal> m_bars;
    qreal m_bass = 0.0;
    qreal m_mid = 0.0;
    qreal m_treble = 0.0;
    qreal m_prevBass = 0.0;
    qreal m_bassEnergyAvg = 0.15;
    qreal m_rollingPeak = 0.35;
    qreal m_kickEnergyAvg = 0.20;
    qreal m_prevKickEnergy = 0.0;
    int m_beatCooldown = 0;
    bool m_isBeatHit = false;
    bool m_shakeDir = false;

    qreal m_shakeScale = 1.0;
    qreal m_shakeX = 0.0;
    qreal m_shakeY = 0.0;

    int m_mode = 1; // Default to Salmany Nation
    int m_themeIndex = 0;
    int m_bgIndex = 0;
    bool m_particlesEnabled = true;
    bool m_shakeEnabled = true;

    // Customizer persistent state
    QString m_customBgImage = "";
    qreal m_bgDim = 0.65;
    int m_particleCount = 100;
    qreal m_particleSpeed = 1.0;
    qreal m_twinkleRatio = 0.40;
    qreal m_bassSensitivity = 1.0;
    qreal m_beatPunch = 1.0;
    qreal m_discPulse = 1.0;

    QTimer m_decayTimer;
};
