#pragma once

#include <QString>

struct Event
{
	QString id;
	QString time;
	QString description;
	uint64_t amount;
	QString comment;
};
