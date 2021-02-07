#include <QApplication>

#include "MainWindow.h"

int main(int argc, char * argv[])
{
	QApplication app(argc, argv);

	MainWindow window;
	window.showMaximized();
	window.setWindowTitle(QObject::tr("Expenses tracker"));

	return app.exec();
}
