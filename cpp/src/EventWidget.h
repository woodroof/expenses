#pragma once

#include <QWidget>

#include "Event.h"

class EventWidget : public QWidget
{
	Q_OBJECT

public:
	explicit EventWidget(const Event & event, QWidget * parent = nullptr);

private:
	Event event_;
};
