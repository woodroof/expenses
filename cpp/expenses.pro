HEADERS += \
  src/Constants.h \
  src/Event.h \
  src/EventWidget.h \
  src/MainWindow.h \
  src/Session.h \
  src/WeekInfo.h \
  src/WeeklyDialog.h
SOURCES += \
  src/Constants.cpp \
  src/EventWidget.cpp \
  src/MainWindow.cpp \
  src/main.cpp \
  src/WeekInfo.cpp \
  src/WeeklyDialog.cpp

CONFIG += release_and_debug c++17 sdk_no_version_check
QT += network widgets

Release:DESTDIR = release
Debug:DESTDIR = debug
