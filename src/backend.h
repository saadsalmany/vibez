#pragma once

#include <QObject>
#include <QList>
#include <QProcess>
#include <QTimer>
#include <QTemporaryFile>

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
    Q_PROPERTY(bool particlesEnabled READ particlesEnabled WRITE setParticlesEnabled NOTIFY particlesChanged)
    Q_PROPERTY(bool shakeEnabled READ shakeEnabled WRITE setShakeEnabled NOTIFY shakeChanged)

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

    bool particlesEnabled() const { return m_particlesEnabled; }
    Q_INVOKABLE void setParticlesEnabled(bool enabled);

    bool shakeEnabled() const { return m_shakeEnabled; }
    Q_INVOKABLE void setShakeEnabled(bool enabled);

    Q_INVOKABLE void nextMode();
    Q_INVOKABLE void nextTheme();
    Q_INVOKABLE void toggleParticles();
    Q_INVOKABLE void toggleShake();

signals:
    void audioUpdated();
    void modeChanged();
    void themeChanged();
    void particlesChanged();
    void shakeChanged();

private slots:
    void onCavaOutput();
    void onDecayTick();

private:
    void startCava();

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

    int m_mode = 1; // Default to Trap Nation Circle
    int m_themeIndex = 0;
    bool m_particlesEnabled = true;
    bool m_shakeEnabled = true;

    QTimer m_decayTimer;
};
