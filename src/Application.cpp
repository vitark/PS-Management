//
// Created by Vitalii Arkusha on 12.05.2021.
//

#include "Application.h"
#include <QTimer>
#include <QDebug>

Application::Application(int &argc, char **argv, int) : QApplication(argc, argv) {
    mCommunication = new Communication(this);
    mMainWindow = new MainWindow();

    mWorkingTimer.setTimerType(Qt::PreciseTimer);
    mWorkingTimer.setInterval(250); // 150 min (9600), 250 norm.
    connect(&mWorkingTimer, &QTimer::timeout, this, &Application::slotWorkingCycle);

    QTimer::singleShot(0, this, SLOT(slotAppRun()));
}

Application::~Application() {
}

void Application::slotAppRun() {
    connect(mMainWindow, &MainWindow::onSerialPortSettingsChanged, mCommunication, &Communication::openSerialPort);
    connect(mMainWindow, &MainWindow::onSerialPortDoClose, mCommunication, &Communication::closeSerialPort);
    connect(mCommunication, &Communication::onSerialPortErrorOccurred, mMainWindow, &MainWindow::slotSerialPortErrorOccurred);
    connect(mCommunication, &Communication::onSerialPortOpened, this, &Application::slotSerialPortOpened);
    connect(mCommunication, &Communication::onSerialPortClosed, this, &Application::slotSerialPortClosed);

    connect(mCommunication, &Communication::onDeviceInfo, mMainWindow, &MainWindow::slotDisplayDeviceInfo);

    // Lock operation panel
    connect(mMainWindow, &MainWindow::onLockOperationPanelChanged, mCommunication, &Communication::lockOperationPanel);
    connect(mCommunication, &Communication::onOperationPanelLocked, mMainWindow, &MainWindow::slotLockOperationPanel);

    // Buzzer
    connect(mMainWindow, &MainWindow::onBuzzerChanged, mCommunication, &Communication::enableBuzzer);
    connect(mCommunication, &Communication::onBuzzerEnabled, mMainWindow, &MainWindow::slotEnableBuzzer);

    // Memory / Presets
    connect(mCommunication, &Communication::onRecalledSetting, mMainWindow, &MainWindow::slotEnableMemoryKey);
    connect(mMainWindow, &MainWindow::onMemoryKeyChanged, mCommunication, &Communication::recallSetting);

    connect(mMainWindow, &MainWindow::onOutputSwitchChanged, mCommunication, &Communication::setOutputSwitch);
    connect(mMainWindow, &MainWindow::onOutputConnectionMethodChanged, mCommunication,&Communication::changeOutputConnectionMethod);
    connect(mMainWindow, &MainWindow::onOutputProtectionChanged, this, &Application::slotOutputProtectionChanged);
    connect(mCommunication, &Communication::onOverCurrentProtectionValue, mMainWindow, &MainWindow::slotDisplayOverCurrentProtectionValue);
    connect(mCommunication, &Communication::onOverVoltageProtectionValue, mMainWindow, &MainWindow::slotDisplayOverVoltageProtectionValue);
    connect(mMainWindow, &MainWindow::onOverCurrentProtectionChanged, mCommunication, &Communication::setOverCurrentProtectionValue);
    connect(mMainWindow, &MainWindow::onOverVoltageProtectionChanged, mCommunication, &Communication::setOverVoltageProtectionValue);

    connect(mCommunication, &Communication::onSetCurrent, mMainWindow, &MainWindow::slotDisplaySetCurrent);
    connect(mCommunication, &Communication::onOutputCurrent, mMainWindow, &MainWindow::slotDisplayOutputCurrent);

    connect(mCommunication, &Communication::onSetVoltage, mMainWindow, &MainWindow::slotDisplaySetVoltage);
    connect(mCommunication, &Communication::onOutputVoltage, mMainWindow, &MainWindow::slotDisplayOutputVoltage);

    connect(mCommunication, &Communication::onDeviceStatus, this, &Application::slotOutputStatus);

    connect(mMainWindow, &MainWindow::onVoltageChanged, mCommunication, &Communication::setVoltage);
    connect(mMainWindow, &MainWindow::onCurrentChanged, mCommunication, &Communication::setCurrent);

    mMainWindow->show();
    mMainWindow->autoOpenSerialPort();
}

void Application::slotSerialPortOpened(const QString &name, int baudRate) {
    mMainWindow->slotSerialPortOpened(name, baudRate);

    mCommunication->getDeviceInfo();
    mCommunication->getOverCurrentProtectionValue(Channel1);
    mCommunication->getOverCurrentProtectionValue(Channel2);
    mCommunication->getOverVoltageProtectionValue(Channel1);
    mCommunication->getOverVoltageProtectionValue(Channel2);

    mWorkingTimer.start();
}

void Application::slotSerialPortClosed() {
    mWorkingTimer.stop();
    mMainWindow->slotSerialPortClosed();
}

void Application::slotWorkingCycle() {
    mCommunication->getDeviceStatus();
    mCommunication->getActiveSetting();
    mCommunication->isOperationPanelLocked();
    mCommunication->isBuzzerEnabled();
}

void Application::slotOutputStatus(DeviceStatus status) {
    if (status.outputSwitchStatus()) {
        mCommunication->getOutputCurrent(Channel1);
        mCommunication->getOutputCurrent(Channel2);
        mCommunication->getOutputVoltage(Channel1);
        mCommunication->getOutputVoltage(Channel2);

        disconnect(mCommunication, &Communication::onSetCurrent, mMainWindow, &MainWindow::slotDisplayOutputCurrent);
        disconnect(mCommunication, &Communication::onSetVoltage, mMainWindow, &MainWindow::slotDisplayOutputVoltage);
    } else {
        connect(mCommunication, &Communication::onSetCurrent, mMainWindow, &MainWindow::slotDisplayOutputCurrent);
        connect(mCommunication, &Communication::onSetVoltage, mMainWindow, &MainWindow::slotDisplayOutputVoltage);
    }

    mCommunication->getCurrent(Channel1);
    mCommunication->getCurrent(Channel2);
    mCommunication->getVoltage(Channel1);
    mCommunication->getVoltage(Channel2);

    if (status.outputProtectionMode() == OverVoltageProtectionOnly || status.outputProtectionMode() == OutputProtectionAllEnabled) {
        mCommunication->getOverVoltageProtectionValue(Channel1);
        mCommunication->getOverVoltageProtectionValue(Channel2);
    }
    if (status.outputProtectionMode() == OverCurrentProtectionOnly || status.outputProtectionMode() == OutputProtectionAllEnabled) {
        mCommunication->getOverCurrentProtectionValue(Channel1);
        mCommunication->getOverCurrentProtectionValue(Channel2);
    }

    mMainWindow->slotShowOutputStabilizingMode(status.stabilizingMode(Channel1), status.stabilizingMode(Channel2));
    mMainWindow->slotShowOutputSwitchStatus(status.outputSwitchStatus());
    mMainWindow->slotShowOutputProtectionMode(status.outputProtectionMode());
    mMainWindow->slotShowOutputConnectionMethod(status.outputConnectionMethod());
}

void Application::slotOutputProtectionChanged(TOutputProtection protection) {
    mCommunication->enableOverVoltageProtection(protection == OverVoltageProtectionOnly || protection == OutputProtectionAllEnabled);
    mCommunication->enableOverCurrentProtection(protection == OverCurrentProtectionOnly || protection == OutputProtectionAllEnabled);
}








