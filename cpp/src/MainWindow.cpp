#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QScrollArea>
#include <QComboBox>
#include <QFormLayout>

#include "EventWidget.h"
#include "MainWindow.h"

MainWindow::MainWindow(QWidget * parent)
	: QWidget(parent)
{
	logout();
}

MainWindow::~MainWindow()
{
}

void MainWindow::setLoginLayout()
{
	delete layout();
	auto login_layout = new QHBoxLayout(this);

	auto vertical_login_layout = new QVBoxLayout();

	auto login_password = new QFormLayout();
	auto buttons = new QHBoxLayout();
	auto error_line = new QLabel();

	auto login = new QLineEdit();
	auto password = new QLineEdit();
	password->setEchoMode(QLineEdit::Password);

	auto login_button = new QPushButton(QObject::tr("Login"));
	auto new_user_button = new QPushButton(QObject::tr("New user"));

	buttons->addStretch(1);
	buttons->addWidget(login_button);
	buttons->addWidget(new_user_button);

	login_password->addRow(QObject::tr("Login:"), login);
	login_password->addRow(QObject::tr("Password:"), password);
	login_password->addRow(buttons);

	vertical_login_layout->addStretch(1);
	vertical_login_layout->addLayout(login_password);
	vertical_login_layout->addWidget(error_line);
	vertical_login_layout->addStretch(1);

	login_layout->addStretch(1);
	login_layout->addLayout(vertical_login_layout);
	login_layout->addStretch(1);
}

void MainWindow::setMainLayout()
{
	auto main_layout = new QVBoxLayout();

	auto header = new QHBoxLayout();
	auto events = new QVBoxLayout();

	auto event_controls = new QHBoxLayout();
	auto event_list = new QScrollArea();

	auto weekly_button = new QPushButton(QObject::tr("Weekly"));
	auto user_label = new QLabel(QObject::tr("User:"));
	auto users = new QComboBox();

	auto add_button = new QPushButton(QObject::tr("Add"));
	auto filter_label = new QLabel(QObject::tr("Filter:"));

	auto list_widget = new QWidget();
	list_widget->setLayout(list_layout_);

	event_list->setWidget(list_widget);
	event_list->setWidgetResizable(true);

	header->addStretch(1);
	header->addWidget(weekly_button);
	header->addWidget(user_label);
	header->addWidget(users);

	event_controls->addWidget(add_button);
	event_controls->addWidget(filter_label);
	event_controls->addStretch(1);

	events->addLayout(event_controls);
	events->addWidget(event_list, 1);

	main_layout->addLayout(header);
	main_layout->addLayout(events, 1);

	delete layout();
	setLayout(main_layout);
}

void MainWindow::logout()
{
	setLoginLayout();
}

void MainWindow::login(const std::vector<Event> & events)
{
	list_layout_ = new QVBoxLayout();
	for (const auto & event : events)
	{
		list_layout_->addWidget(new EventWidget(event));
	}
	list_layout_->addStretch(1);

	setMainLayout();
}
