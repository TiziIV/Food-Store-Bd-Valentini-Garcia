<#
.SYNOPSIS
    Respaldo logico automatizable de la base de datos foodstore en formato Custom (-Fc).
.DESCRIPTION
    Trabajo Practico - Unidad 6 (Parte 2): Mantenimiento, respaldo y recuperacion.
    Crea las carpetas backups/ y logs/ si no existen, ejecuta pg_dump en formato custom (-Fc)
    con marca temporal YYYYMMDD_HHMMSS, registra la ejecucion en logs/backup_YYYYMMDD.log,
    valida el codigo de salida ($LASTEXITCODE) y el tamano del archivo generado (> 0 bytes),
    y finaliza con codigo de error distinto de cero si pg_dump falla.
.NOTES
    SEGURIDAD DE CREDENCIALES (Regla Critica):
    Este script NO contiene contrasenas ni define variables de contrasena en texto plano.
    Para su ejecucion desatendida en Windows, la autenticacion debe configurarse mediante:
      1. Archivo %APPDATA%\postgresql\pgpass.conf con formato:
         localhost:5432:*:postgres:<contrasena_segura>
         (restringiendo los permisos ACL del archivo exclusivamente al usuario de servicio), o
      2. Variables de entorno externas inyectadas de forma segura por el Programador de Tareas / Vault.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Push-Location $PSScriptRoot
try {
    # Resolver binarios de PostgreSQL 16+ si no estan cargados en el PATH de la sesion
    if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
        $pgBin = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin" -Directory -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending |
                 Select-Object -First 1
        if ($pgBin) {
            $env:Path = "$($pgBin.FullName);$env:Path"
        } else {
            Write-Error "No se encontro el binario 'pg_dump' en el PATH ni en C:\Program Files\PostgreSQL."
            exit 1
        }
    }

    # 1. Crear directorios requeridos si no existen
    $backupDir    = "backups"
    $logDir       = "logs"
    $evidenciaDir = "evidencias"

    foreach ($dir in @($backupDir, $logDir, $evidenciaDir)) {
        if (-not (Test-Path -Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    # 2. Definir marcas de tiempo y rutas de salida
    $now       = Get-Date
    $dateStamp = $now.ToString("yyyyMMdd")
    $timeStamp = $now.ToString("yyyyMMdd_HHmmss")
    $dumpFile  = "$backupDir/foodstore_$timeStamp.dump"
    $logFile   = "$logDir/backup_$dateStamp.log"

    function Write-BackupLog {
        param([string]$Message, [string]$Level = "INFO")
        $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Level, $Message
        Add-Content -Path $logFile -Value $entry -Encoding UTF8
        Write-Host $entry
    }

    Write-BackupLog "=================================================================="
    Write-BackupLog "Iniciando respaldo logico de la base 'foodstore' (formato Custom -Fc)"
    Write-BackupLog "Archivo destino: $dumpFile"
    Write-BackupLog "Comando: pg_dump -h localhost -p 5432 -U postgres -d foodstore -Fc -f $dumpFile"

    # 3. Ejecutar pg_dump capturando tiempo y salida estandar/error
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ErrorActionPreference = "Continue"
    $pgOutput = & pg_dump -h localhost -p 5432 -U postgres -d foodstore -Fc -f $dumpFile 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    $sw.Stop()

    if ($pgOutput) {
        foreach ($line in $pgOutput) {
            Write-BackupLog "pg_dump: $line"
        }
    }

    # 4. Validar codigo de salida ($LASTEXITCODE)
    if ($exitCode -ne 0) {
        Write-BackupLog "pg_dump finalizo con codigo de error ($exitCode). Respaldo abortado." "ERROR"
        exit $exitCode
    }

    # 5. Validar existencia y tamano del archivo generado (> 0 bytes)
    if (-not (Test-Path -Path $dumpFile)) {
        Write-BackupLog "El archivo de respaldo '$dumpFile' no fue encontrado tras la ejecucion." "ERROR"
        exit 2
    }

    $fileInfo = Get-Item -Path $dumpFile
    if ($fileInfo.Length -le 0) {
        Write-BackupLog "El archivo de respaldo '$dumpFile' tiene tamano 0 bytes (invalido)." "ERROR"
        exit 3
    }

    $sizeMB  = [Math]::Round($fileInfo.Length / 1MB, 2)
    $sha256  = (Get-FileHash -Path $dumpFile -Algorithm SHA256).Hash
    $elapsed = [Math]::Round($sw.Elapsed.TotalSeconds, 3)

    Write-BackupLog "Respaldo completado exitosamente en $elapsed s ($($sw.ElapsedMilliseconds) ms)."
    Write-BackupLog "Tamano verificado: $($fileInfo.Length) bytes ($sizeMB MB) | SHA256: $sha256"
    Write-BackupLog "Estado final: EXITOSO (ExitCode = 0)"
    Write-BackupLog "=================================================================="

    # 6. Guardar evidencia verificable del archivo .dump (cuyo binario se ignora en Git por peso)
    $evidenciaFile = "$evidenciaDir/evidencia_respaldo.txt"
    $evidenciaText = @"
================================================================================
EVIDENCIA DE RESPALDO AUTOMATIZADO (Parte 2 - backup_foodstore.ps1)
================================================================================
Fecha y hora de ejecucion : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff zzz")
Base de datos origen      : foodstore (PostgreSQL 16+)
Archivo generado          : $dumpFile
Existencia verificada     : $(Test-Path -Path $dumpFile)
Tamano exacto             : $($fileInfo.Length) bytes ($sizeMB MB)
Fecha de escritura (UTC)  : $($fileInfo.LastWriteTimeUtc.ToString("yyyy-MM-dd HH:mm:ss.fff 'UTC'"))
Fecha de escritura (Local): $($fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss.fff"))
Hash SHA-256              : $sha256
Duracion del respaldo     : $elapsed segundos ($($sw.ElapsedMilliseconds) ms)
Codigo de salida pg_dump  : $exitCode (OK)
Archivo de log asociado   : $logFile
================================================================================
--- Contenido registrado en $logFile ---
$(Get-Content -Path $logFile -Raw)
"@
    Set-Content -Path $evidenciaFile -Value $evidenciaText -Encoding UTF8
    exit 0
}
finally {
    Pop-Location
}
