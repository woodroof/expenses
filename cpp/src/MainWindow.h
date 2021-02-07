#pragma once

#include <QBoxLayout>
#include <QWidget>

#include "Event.h"

class MainWindow : public QWidget
{
	Q_OBJECT

public:
	explicit MainWindow(QWidget * parent = nullptr);
	~MainWindow() override;

private:
	void setLoginLayout();
	void setMainLayout();

	void logout();
	void login(const std::vector<Event> & events);

private:
	QBoxLayout * list_layout_;
};
