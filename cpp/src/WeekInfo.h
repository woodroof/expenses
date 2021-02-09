#pragma once

#include <map>
#include <utility>

struct WeekInfo
{
	uint64_t sum = 0;
	size_t count = 0;
};

// Key: year << 6 | week_num
unsigned getWeekInfosKey(unsigned year, unsigned week_info);

std::pair<unsigned, unsigned> getYearAndWeekNumberFromWeekInfosKey(unsigned key);

using WeekInfos = std::map<unsigned, WeekInfo>;
