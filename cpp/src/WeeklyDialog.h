#pragma once

#include <QDialog>

#include "WeekInfo.h"

class WeeklyDialog : public QDialog
{
	Q_OBJECT

public:
	WeeklyDialog(QWidget * parent, const WeekInfos & week_infos);
};
