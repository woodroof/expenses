#pragma once

#include <QString>

struct Event
{
	QString time;
	QString description;
	uint64_t amount;
	QString comment;
};
