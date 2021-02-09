#include <limits>

#include <QHBoxLayout>
#include <QFormLayout>
#include <QLabel>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTimeEdit>

#include "Constants.h"
#include "EventWidget.h"

std::optional<std::vector<std::unique_ptr<QWidget>>> parseEvents(
	const QJsonDocument & document,
	const std::shared_ptr<Session> & session)
{
	if (!document.isArray())
		return {};

	std::vector<std::unique_ptr<QWidget>> events;

	for (QJsonValueRef value : document.array())
	{
		if (!value.isObject())
			return {};

		const auto event_object = value.toObject();
		const auto id_it = event_object.find("id");
		const auto date_it = event_object.find("date");
		const auto description_it = event_object.find("description");
		const auto amount_it = event_object.find("amount");
		const auto comment_it = event_object.find("comment");

		if (
			id_it == event_object.end() ||
			date_it == event_object.end() ||
			description_it == event_object.end() ||
			amount_it == event_object.end() ||
			comment_it == event_object.end() ||
			!id_it->isString() ||
			!date_it->isString() ||
			!description_it->isString() ||
			!amount_it->isDouble() ||
			!comment_it->isString())
		{
			return {};
		}

		//! \todo support non-integer amount
		const auto amount_uint = static_cast<uint64_t>(amount_it->toDouble());
		if (amount_uint != amount_it->toDouble())
		{
			return {};
		}
		//! \todo validate date

		events.push_back(
			std::make_unique<EventWidget>(
				Event{
					id_it->toString(),
					date_it->toString(),
					description_it->toString(),
					amount_uint,
					comment_it->toString()},
				session));
	}

	return std::move(events);
}

EventWidget::EventWidget(Event event, std::shared_ptr<Session> session, QWidget * parent)
	: QWidget(parent)
	, event_(std::move(event))
	, session_(std::move(session))
	, network_(new QNetworkAccessManager(this))
{
	connect(network_, &QNetworkAccessManager::finished, this, &EventWidget::onNetworkRequestFinished);

	if (event_.time.isEmpty())
		event_.time = QDateTime::currentDateTimeUtc().toString(date_format);

	edit_button_ = new QPushButton(QObject::tr("Edit"));
	delete_button_ = new QPushButton(QObject::tr("Delete"));
	ok_button_ = new QPushButton(QObject::tr("OK"));
	cancel_button_ = new QPushButton(QObject::tr("Cancel"));

	connect(edit_button_, &QPushButton::clicked, this, &EventWidget::onEditClicked);
	connect(delete_button_, &QPushButton::clicked, this, &EventWidget::onDeleteClicked);
	connect(ok_button_, &QPushButton::clicked, this, &EventWidget::onOkClicked);
	connect(cancel_button_, &QPushButton::clicked, this, &EventWidget::onCancelClicked);

	message_ = new QLabel();
	message_->setTextFormat(Qt::PlainText);

	auto buttons = new QHBoxLayout();
	buttons->addWidget(edit_button_);
	buttons->addWidget(delete_button_);
	buttons->addWidget(ok_button_);
	buttons->addWidget(cancel_button_);
	buttons->addStretch(1);

	auto event_layout = new QFormLayout(this);

	time_ = new QDateTimeEdit();
	time_->setDisplayFormat(date_format);
	time_->setCalendarPopup(true);

	description_ = new QTextEdit();
	description_->setAcceptRichText(false);

	amount_ = new QLineEdit();
	//! \todo add validator

	comment_ = new QTextEdit();
	comment_->setAcceptRichText(false);

	restoreValues();

	event_layout->addRow(QObject::tr("Time (UTC):"), time_);
	event_layout->addRow(QObject::tr("Description:"), description_);
	event_layout->addRow(QObject::tr("Amount:"), amount_);
	event_layout->addRow(QObject::tr("Comment:"), comment_);
	event_layout->addRow(message_);
	event_layout->addRow(buttons);

	if (!event_.id.isEmpty())
		onCommited();
	else
		onEditClicked();
}

bool EventWidget::find(QString filter) const
{
	return
		time_->dateTime().toString(date_format).contains(filter) ||
		description_->toPlainText().contains(filter) ||
		amount_->text().contains(filter) ||
		comment_->toPlainText().contains(filter);
}

void EventWidget::fillWeekInfos(WeekInfos & infos) const
{
	const auto date = QDateTime::fromString(event_.time, date_format).date();
	int year;
	int weekNumber = date.weekNumber(&year);
	auto & info = infos[getWeekInfosKey(year, weekNumber)];
	info.sum += event_.amount;
	++info.count;
}

void EventWidget::onCommited()
{
	event_.time = time_->dateTime().toString(date_format);
	event_.description = description_->toPlainText();
	event_.amount = amount_->text().toULong();
	event_.comment = comment_->toPlainText();

	message_->setText("");

	time_->setReadOnly(true);
	description_->setReadOnly(true);
	amount_->setReadOnly(true);
	comment_->setReadOnly(true);

	edit_button_->setVisible(true);
	delete_button_->setVisible(true);
	ok_button_->setVisible(false);
	cancel_button_->setVisible(false);
}

void EventWidget::onEditClicked()
{
	time_->setReadOnly(false);
	description_->setReadOnly(false);
	amount_->setReadOnly(false);
	comment_->setReadOnly(false);

	edit_button_->setVisible(false);
	delete_button_->setVisible(false);
	ok_button_->setVisible(true);
	cancel_button_->setVisible(true);
}

void EventWidget::onDeleteClicked()
{
	QNetworkRequest request = session_->base_request;
	request.setUrl(QUrl(base_url + "/expenses/" + session_->active_user + "/" + event_.id));

	reply_ = network_->deleteResource(request);
	connect(reply_, &QNetworkReply::metaDataChanged, this, [this, reply = reply_]{ onNetworkMetadataReceived(reply, "delete"); });
}

void EventWidget::onOkClicked()
{
	QNetworkRequest request = session_->base_request;
	if (event_.id.isEmpty())
	{
		if (id_.isEmpty())
			id_ = QUuid::createUuid().toString();
		request.setUrl(QUrl(base_url + "/expenses/" + session_->active_user + "/" + id_));
	}
	else
		request.setUrl(QUrl(base_url + "/expenses/" + session_->active_user + "/" + event_.id));

	const auto amount_text = amount_->text();
	bool correct_amount = false;
	const auto amount = amount_text.toInt(&correct_amount);
	//! \todo support non-integer amount
	if (!correct_amount || amount < 0)
	{
		message_->setText("Invalid amount, should be integer >= 0 and <= 2 147 483 647");
		return;
	}

	ok_button_->setEnabled(false);
	cancel_button_->setEnabled(false);

	QJsonObject object;
	object.insert("date", time_->dateTime().toString(date_format));
	object.insert("description", description_->toPlainText());
	object.insert("amount", static_cast<double>(amount));
	object.insert("comment", comment_->toPlainText());

	QJsonDocument document(object);
	reply_ = network_->put(request, document.toJson(QJsonDocument::Compact));
	connect(reply_, &QNetworkReply::metaDataChanged, this, [this, reply = reply_]{ onNetworkMetadataReceived(reply, "put"); });
}

void EventWidget::onCancelClicked()
{
	if (event_.id.isEmpty())
	{
		static_cast<QWidget *>(parent())->layout()->removeWidget(this);
		delete this;
		return;
	}

	restoreValues();

	onCommited();
}

void EventWidget::restoreValues()
{
	time_->setDateTime(QDateTime::fromString(event_.time, date_format));
	description_->setText(event_.description);
	amount_->setText(QString::number(event_.amount));
	comment_->setText(event_.comment);
}

void EventWidget::onNetworkMetadataReceived(QNetworkReply * reply, QString method)
{
	if (reply != reply_)
	{
		return;
	}

	const auto code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
	if (method == "put")
	{
		ok_button_->setEnabled(true);
		cancel_button_->setEnabled(true);

		if (code == 201)
		{
			event_.id = id_;
			onCommited();
		}
		else if (code == 204)
		{
			onCommited();
		}
		else
		{
			if (code == 400)
				message_->setText(tr("Invalid date"));
			else
				message_->setText(tr("Unexpected server response code {}").arg(code));
		}
	}
	else
	{
		if (code == 204)
		{
			static_cast<QWidget *>(parent())->layout()->removeWidget(this);
			this->deleteLater();
			return;
		}

		message_->setText(tr("Unexpected server response code {}").arg(code));
		edit_button_->setEnabled(true);
		delete_button_->setEnabled(true);
	}

	reply_ = nullptr;
}

void EventWidget::onNetworkRequestFinished(QNetworkReply * reply)
{
	reply->deleteLater();

	if (!reply_)
	{
		return;
	}

	message_->setText(tr("Network Error"));
	ok_button_->setEnabled(true);
	cancel_button_->setEnabled(true);
	edit_button_->setEnabled(true);
	delete_button_->setEnabled(true);
	reply_ = nullptr;
}
