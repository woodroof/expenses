#pragma once

#include <optional>
#include <memory>
#include <vector>

#include <QDateTimeEdit>
#include <QJsonDocument>
#include <QLabel>
#include <QLineEdit>
#include <QNetworkReply>
#include <QPushButton>
#include <QTextEdit>
#include <QWidget>

#include "Event.h"
#include "Session.h"
#include "WeekInfo.h"

class EventWidget : public QWidget
{
	Q_OBJECT

public:
	EventWidget(Event event, std::shared_ptr<Session> session, QWidget * parent = nullptr);

	bool find(QString filter) const;
	void fillWeekInfos(WeekInfos & infos) const;

private:
	void onCommited();
	void onEditClicked();
	void onDeleteClicked();
	void onOkClicked();
	void onCancelClicked();
	void restoreValues();

	void onNetworkMetadataReceived(QNetworkReply * reply, QString method);
	void onNetworkRequestFinished(QNetworkReply * reply);

private:
	Event event_;
	QString id_;
	std::shared_ptr<Session> session_;
	QNetworkAccessManager * network_;
	QNetworkReply * reply_;

	QPushButton * edit_button_;
	QPushButton * delete_button_;
	QPushButton * ok_button_;
	QPushButton * cancel_button_;

	QDateTimeEdit * time_;
	QTextEdit * description_;
	QLineEdit * amount_;
	QTextEdit * comment_;
	QLabel * message_;
};

std::optional<std::vector<std::unique_ptr<QWidget>>> parseEvents(
	const QJsonDocument & document,
	const std::shared_ptr<Session> & session);
