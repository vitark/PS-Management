// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

//
// Created by Vitalii Arkusha on 14.10.2022.
//

#ifndef PSM_FACTORY_H
#define PSM_FACTORY_H

#include <QByteArrayList>
#include <QSerialPort>

#include "BaseSCPI.h"
#include "UTP3303C.h"
#include "UTP3305C.h"

namespace Protocol {
    class Factory  {
    public:
        explicit Factory(QSerialPort &serialPort);
        ~Factory();
        BaseSCPI *createInstance();

        QString errorString() const;
        QString deviceID() const;

    private:
        QSerialPort     &mSerialPort;
        QByteArrayList  mKnownGetIDQueryList;
        QString         mErrorString;
        QString         mDeviceID;

    private:
        QString     deviceIdentification();
    };
}

#endif //PSM_FACTORY_H
