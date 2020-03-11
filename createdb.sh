#!/bin/bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=pa55word(!)Secret' -p 1433:1433 -d mcr.microsoft.com/mssql/server:2017-CU8-ubuntu
