#include "WeekInfo.h"

unsigned getWeekInfosKey(unsigned year, unsigned week_info)
{
	return year << 6 | week_info;
}

std::pair<unsigned, unsigned> getYearAndWeekNumberFromWeekInfosKey(unsigned key)
{
	return {key >> 6, key & 0x3f};
}
