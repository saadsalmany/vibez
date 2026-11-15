#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include "backend.h"
#include "theme.h"

int main(int argc, char *argv[]) {
    // Lockstep VSync presentation under Wayland to eliminate fullscreen swap jitter
    if (!qEnvironmentVariableIsSet("QSG_RENDER_LOOP")) {
        qputenv("QSG_RENDER_LOOP", "basic");
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName("vibez");
    app.setApplicationVersion("1.0.0");
    app.setDesktopFileName("vibez");

    QQuickStyle::setStyle("Material");

    Backend backend;
    Theme theme;

    for (int i = 1; i < argc; ++i) {
        QString arg = argv[i];
        if ((arg == "-m" || arg == "--mode") && i + 1 < argc) {
            backend.setMode(QString(argv[i + 1]).toInt());
            i++;
        }
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.rootContext()->setContextProperty("theme", &theme);

    const QUrl url(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
