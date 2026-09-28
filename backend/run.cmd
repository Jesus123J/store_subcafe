@echo off
REM Arranca el backend en local (Windows).
REM   run.cmd            -> perfil por defecto (MySQL local root/123456, BD financialtracker1)
REM   run.cmd local      -> usa application-local.yml
REM Requiere: JDK 17+ en JAVA_HOME y el contenedor MySQL "mysql-proyectos" encendido.
cd /d "%~dp0"
if "%~1"=="" (
  call mvnw.cmd -q spring-boot:run
) else (
  call mvnw.cmd -q spring-boot:run -Dspring-boot.run.profiles=%~1
)
