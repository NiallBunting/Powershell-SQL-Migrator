#!/bin/bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=pa55word(!)Secret' -p 1433:1433 -d mcr.microsoft.com/mssql/server:2017-CU8-ubuntu


echo << EOF

The next commands need running manually at the moment

docker exec -it a8fd6f5fa1a9051ad401d /bin/bash

/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'pa55word(!)Secret'

CREATE DATABASE TEST;
GO


EOF

exit 0
