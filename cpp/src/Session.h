#pragma once

#include <QNetworkRequest>
#include <QString>

struct Session
{
	QNetworkRequest base_request;
	QString active_user;
};
