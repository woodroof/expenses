#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QScrollArea>
#include <QLabel>

#include "WeeklyDialog.h"

WeeklyDialog::WeeklyDialog(QWidget * parent, const WeekInfos & week_infos)
	: QDialog(parent)
{
	auto main_layout = new QVBoxLayout(this);
	auto button_layout = new QHBoxLayout();

	auto ok_button = new QPushButton("OK");
	ok_button->setDefault(true);
	connect(ok_button, &QPushButton::clicked, this, &QDialog::accept);

	button_layout->addStretch(1);
	button_layout->addWidget(ok_button);
	button_layout->addStretch(1);

	auto list_layout = new QVBoxLayout();
	for (auto it = week_infos.rbegin(); it != week_infos.rend(); ++it)
	{
		const auto [year, week_number] = getYearAndWeekNumberFromWeekInfosKey(it->first);
		const double average = static_cast<double>(it->second.sum) / 7;
		auto label = new QLabel(QString("Year %1, week %2. Total spent: %3. Daily average: %4.").arg(year).arg(week_number).arg(it->second.sum).arg(average));
		label->setTextFormat(Qt::PlainText);
		list_layout->addWidget(label);
	}

	auto event_list = new QScrollArea(this);
	auto list_widget = new QWidget(event_list);
	list_widget->setLayout(list_layout);

	main_layout->addWidget(event_list);
	main_layout->addLayout(button_layout);
}
