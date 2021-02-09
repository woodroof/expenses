#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QScrollArea>
#include <QComboBox>
#include <QFormLayout>
#include <QJsonObject>
#include <QJsonArray>

#include "Constants.h"
#include "EventWidget.h"
#include "MainWindow.h"
#include "WeeklyDialog.h"

MainWindow::MainWindow(QWidget * parent)
	: QWidget(parent)
	, network_(new QNetworkAccessManager(this))
	, session_(new Session())
{
	connect(network_, &QNetworkAccessManager::finished, this, &MainWindow::onNetworkRequestFinished);

	logout();
}

MainWindow::~MainWindow()
{
}

void MainWindow::setLoginLayout()
{
	clear();

	auto login_layout = new QHBoxLayout(this);

	auto vertical_login_layout = new QVBoxLayout();

	auto login_password = new QFormLayout();
	auto buttons = new QHBoxLayout();
	message_line_ = new QLabel();
	message_line_->setTextFormat(Qt::PlainText);

	login_ = new QLineEdit();
	password_ = new QLineEdit();
	password_->setEchoMode(QLineEdit::Password);

	login_button_ = new QPushButton(tr("Login"));
	connect(login_button_, &QPushButton::clicked, this, &MainWindow::onLoginClicked);
	create_user_button_ = new QPushButton(tr("Create user"));
	connect(create_user_button_, &QPushButton::clicked, this, &MainWindow::onCreateUserClicked);

	buttons->addStretch(1);
	buttons->addWidget(login_button_);
	buttons->addWidget(create_user_button_);

	login_password->addRow(tr("Login:"), login_);
	login_password->addRow(tr("Password:"), password_);
	login_password->addRow(buttons);

	login_widgets_ = {message_line_, login_, password_, login_button_, create_user_button_, login_password->labelForField(login_), login_password->labelForField(password_)};

	vertical_login_layout->addStretch(1);
	vertical_login_layout->addLayout(login_password);
	vertical_login_layout->addWidget(message_line_);
	vertical_login_layout->addStretch(1);

	login_layout->addStretch(1);
	login_layout->addLayout(vertical_login_layout);
	login_layout->addStretch(1);
}

void MainWindow::setMainLayout()
{
	clear();

	auto main_layout = new QVBoxLayout(this);

	auto header = new QHBoxLayout();
	auto events = new QVBoxLayout();

	auto event_controls = new QHBoxLayout();
	auto event_list = new QScrollArea();

	weekly_button_ = new QPushButton(tr("Weekly"));
	connect(weekly_button_, &QPushButton::clicked, this, &MainWindow::onWeeklyClicked);

	auto user_label = new QLabel(tr("User:"));
	users_ = new QComboBox();
	for (const auto & user : my_users_)
	{
		users_->addItem(user);
	}
	connect(users_, &QComboBox::currentTextChanged, this, &MainWindow::onUserChanged);
	logout_button_ = new QPushButton(tr("Logout"));
	connect(logout_button_, &QPushButton::clicked, this, &MainWindow::logout);

	add_button_ = new QPushButton(tr("Add"));
	connect(add_button_, &QPushButton::clicked, this, &MainWindow::onAddClicked);

	auto filter_label = new QLabel(tr("Filter:"));
	filter_ = new QLineEdit();
	connect(filter_, &QLineEdit::textChanged, this, &MainWindow::onFilterChanged);

	user_widgets_ = {event_list, weekly_button_, user_label, users_, logout_button_, add_button_, filter_label, filter_};

	list_layout_ = new QVBoxLayout();
	list_layout_->addStretch(1);

	list_widget_ = new QWidget(event_list);
	list_widget_->setLayout(list_layout_);

	event_list->setWidget(list_widget_);
	event_list->setWidgetResizable(true);

	header->addStretch(1);
	header->addWidget(weekly_button_);
	header->addWidget(user_label);
	header->addWidget(users_);
	header->addWidget(logout_button_);

	event_controls->addWidget(add_button_);
	event_controls->addWidget(filter_label);
	event_controls->addWidget(filter_);
	event_controls->addStretch(1);

	events->addLayout(event_controls);
	events->addWidget(event_list, 1);

	main_layout->addLayout(header);
	main_layout->addLayout(events, 1);
}

void MainWindow::clear()
{
	delete layout();
	for (auto widget : login_widgets_)
	{
		delete widget;
	}
	for (auto widget : user_widgets_)
	{
		delete widget;
	}
	login_widgets_.clear();
	user_widgets_.clear();
}

void MainWindow::logout()
{
	setLoginLayout();
}

void MainWindow::login()
{
	setMainLayout();
}

void MainWindow::onLoginClicked()
{
	const auto [login, password] = getLoginPassword();
	if (login.isEmpty())
		return;

	const QString login_password_base64 = (login + ":" + password).toUtf8().toBase64();
	session_->base_request.setRawHeader("Authorization", ("Basic " + login_password_base64).toLocal8Bit());

	login_button_->setEnabled(false);
	create_user_button_->setEnabled(false);

	QNetworkRequest request = session_->base_request;
	request.setUrl(QUrl(base_url + "/my_users"));

	reply_ = network_->get(request);
	connect(reply_, &QNetworkReply::metaDataChanged, this, [this, reply = reply_]{ onNetworkMetadataReceived(reply); });
}

void MainWindow::onCreateUserClicked()
{
	const auto [login, password] = getLoginPassword();
	if (login.isEmpty())
		return;

	login_button_->setEnabled(false);
	create_user_button_->setEnabled(false);

	QNetworkRequest request;
	request.setUrl(QUrl(base_url + "/users/" + login));

	QJsonObject body;
	body.insert("password", password);
	QJsonDocument document(body);
	reply_ = network_->put(request, document.toJson(QJsonDocument::Compact));
	connect(reply_, &QNetworkReply::metaDataChanged, this, [this, reply = reply_]{ onNetworkMetadataReceived(reply); });
}

void MainWindow::onUserChanged(const QString user)
{
	session_->active_user = user;

	users_->setEnabled(false);
	logout_button_->setEnabled(false);
	add_button_->setEnabled(false);
	weekly_button_->setEnabled(false);
	filter_->setEnabled(true);

	while (auto child = list_layout_->takeAt(0))
	{
		delete child->widget();
		delete child;
	}
	list_layout_->addStretch(1);

	QNetworkRequest request = session_->base_request;
	request.setUrl(QUrl(base_url + "/expenses/" + user));
	reply_ = network_->get(request);
	connect(reply_, &QNetworkReply::metaDataChanged, this, [this, reply = reply_]{ onNetworkMetadataReceived(reply); });
}

void MainWindow::onFilterChanged(QString filter)
{
	for (int i = 0; i < list_layout_->count(); ++i)
	{
		if (auto widget = list_layout_->itemAt(i)->widget())
		{
			widget->setVisible(filter.isEmpty() ? true : static_cast<EventWidget *>(widget)->find(filter));
		}
	}
}

void MainWindow::onAddClicked()
{
	list_layout_->insertWidget(0, new EventWidget(Event{"", "", "", 0, ""}, session_));
}

void MainWindow::onWeeklyClicked()
{
	auto dialog = new WeeklyDialog(this, collectWeeksInfos());
	dialog->exec();
	delete dialog;
}

WeekInfos MainWindow::collectWeeksInfos()
{
	WeekInfos infos;
	for (int i = 0; i < list_layout_->count(); ++i)
	{
		if (auto widget = list_layout_->itemAt(i)->widget())
		{
			static_cast<EventWidget *>(widget)->fillWeekInfos(infos);
		}
	}
	return infos;
}

std::pair<QString, QString> MainWindow::getLoginPassword()
{
	const auto login_text = login_->text();
	if (login_text.isEmpty())
	{
		message_line_->setText(tr("Login can't be empty"));
		return {};
	}
	if (login_text.contains('/'))
	{
		message_line_->setText(tr("Login can not contain /"));
		return {};
	}

	const auto password_text = password_->text();
	if (password_text.isEmpty())
	{
		message_line_->setText(tr("Password can't be empty"));
		return {};
	}

	return {login_text, password_text};
}

void MainWindow::onNetworkMetadataReceived(QNetworkReply * reply)
{
	if (reply != reply_)
	{
		return;
	}

	const auto path = reply->request().url().path();
	const auto code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
	if (path == "/my_users")
	{
		if (code == 200)
			return;
		if (code == 401)
			message_line_->setText(tr("Invalid login or password"));
		else
			message_line_->setText(tr("Unexpected server response code"));
	}
	else if (path.startsWith("/users/"))
	{
		if (code == 201)
			message_line_->setText(tr("User created"));
		else if (code == 401)
			message_line_->setText(tr("User already exists"));
		else
			message_line_->setText(tr("Unexpected server response code"));
	}
	else if (path.startsWith("/expenses/"))
	{
		if (code == 200)
			return;
		logout();
		message_line_->setText(tr("Unexpected server response code"));
	}

	login_button_->setEnabled(true);
	create_user_button_->setEnabled(true);
	reply_ = nullptr;
}

void MainWindow::onNetworkRequestFinished(QNetworkReply * reply)
{
	reply->deleteLater();

	if (reply != reply_)
	{
		return;
	}

	reply_ = nullptr;

	const auto path = reply->request().url().path();
	const auto error = reply->error() != QNetworkReply::NoError;

	if (path == "/my_users")
	{
		if (!error)
		{
			const auto users = QJsonDocument::fromJson(reply->readAll());
			if (parseUsers(users))
			{
				login();
				onUserChanged(my_users_.front());
				return;
			}

			message_line_->setText(tr("Invalid server response"));
		}
		else
		{
			message_line_->setText(tr("Network error"));
		}

		login_button_->setEnabled(true);
		create_user_button_->setEnabled(true);
	}
	else if (path.startsWith("/users/"))
	{
		message_line_->setText(tr("Network error"));
		login_button_->setEnabled(true);
		create_user_button_->setEnabled(true);
	}
	else if (path.startsWith("/expenses/"))
	{
		if (error)
		{
			logout();
			message_line_->setText(tr("Network error"));
			return;
		}

		const auto events_json = QJsonDocument::fromJson(reply->readAll());
		auto events = parseEvents(events_json, session_);
		if (!events)
		{
			logout();
			message_line_->setText(tr("Invalid server response"));
			return;
		}

		for (auto & event : *events)
		{
			auto event_widget = event.release();
			list_layout_->insertWidget(0, event_widget);
			//! \todo connect +1 -1 for disabling users_
		}

		onFilterChanged(filter_->text());

		users_->setEnabled(true);
		logout_button_->setEnabled(true);
		add_button_->setEnabled(true);
		weekly_button_->setEnabled(true);
		filter_->setEnabled(true);
	}
}

bool MainWindow::parseUsers(const QJsonDocument & document)
{
	std::vector<QString> my_users;

	if (!document.isArray())
		return false;
	for (QJsonValueRef value : document.array())
	{
		if (!value.isString())
			return false;
		my_users.push_back(value.toString());
	}

	my_users_.swap(my_users);
	return true;
}
