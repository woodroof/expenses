#pragma once

#include <utility>

#include <QBoxLayout>
#include <QComboBox>
#include <QJsonDocument>
#include <QLabel>
#include <QLineEdit>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPushButton>
#include <QWidget>

#include "Session.h"
#include "WeekInfo.h"

class MainWindow : public QWidget
{
	Q_OBJECT

public:
	explicit MainWindow(QWidget * parent = nullptr);
	~MainWindow() override;

private:
	void setLoginLayout();
	void setMainLayout();

	void clear();
	void logout();
	void login();

	void onLoginClicked();
	void onCreateUserClicked();
	void onUserChanged(QString user);
	void onFilterChanged(QString filter);
	void onAddClicked();
	void onWeeklyClicked();

	WeekInfos collectWeeksInfos();

	std::pair<QString, QString> getLoginPassword();

	void onNetworkMetadataReceived(QNetworkReply * reply);
	void onNetworkRequestFinished(QNetworkReply * reply);

	bool parseUsers(const QJsonDocument & document);

private:
	QNetworkAccessManager * network_;
	std::shared_ptr<Session> session_;
	QNetworkReply * reply_;

	QPushButton * login_button_;
	QPushButton * create_user_button_;
	QLineEdit * login_;
	QLineEdit * password_;
	QLabel * message_line_;
	std::vector<QWidget *> login_widgets_;

	QComboBox * users_;
	QPushButton * logout_button_;
	QPushButton * add_button_;
	QPushButton * weekly_button_;
	QBoxLayout * list_layout_;
	QWidget * list_widget_;
	std::vector<QWidget *> user_widgets_;
	QLineEdit * filter_;

	std::vector<QString> my_users_;
};
