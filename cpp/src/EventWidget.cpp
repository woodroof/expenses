#include <QPushButton>
#include <QHBoxLayout>
#include <QFormLayout>
#include <QLabel>
#include <QTextEdit>

#include "EventWidget.h"

EventWidget::EventWidget(const Event & event, QWidget * parent)
	: QWidget(parent)
	, event_(event)
{
	auto edit_button = new QPushButton(QObject::tr("Edit"));
	auto delete_button = new QPushButton(QObject::tr("Delete"));

	auto buttons = new QHBoxLayout();
	buttons->addWidget(edit_button);
	buttons->addWidget(delete_button);
	buttons->addStretch(1);

	auto event_layout = new QFormLayout();

	auto time = new QLabel(event.time);
	time->setTextInteractionFlags(Qt::TextSelectableByMouse);

	auto description = new QTextEdit(event.description);
	description->setReadOnly(true);

	auto amount = new QLabel(QString::number(event.amount));
	amount->setTextInteractionFlags(Qt::TextSelectableByMouse);

	auto comment = new QTextEdit(event.comment);
	comment->setReadOnly(true);

	event_layout->addRow(QObject::tr("Time:"), time);
	event_layout->addRow(QObject::tr("Description:"), description);
	event_layout->addRow(QObject::tr("Amount:"), amount);
	event_layout->addRow(QObject::tr("Comment:"), comment);
	event_layout->addRow(buttons);

	setLayout(event_layout);
}
