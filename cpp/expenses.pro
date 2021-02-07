HEADERS += src/Event.h src/EventWidget.h src/MainWindow.h
SOURCES += src/EventWidget.cpp src/MainWindow.cpp src/main.cpp

CONFIG += release_and_debug c++17 sdk_no_version_check
QT += widgets

Release:DESTDIR = release
Debug:DESTDIR = debug
