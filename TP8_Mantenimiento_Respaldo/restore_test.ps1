<#
.SYNOPSIS
    Simulacro automatizado de recuperacion ante desastres contra reloj (RTO / RPO).
.DESCRIPTION
    Trabajo Practico - Unidad 6 (Parte 4): Simulacro de desastre contra reloj.
    1. Localiza el ultimo archivo .dump en backups/ y calcula su antiguedad (RPO observado).
    2. Registra el conteo de referencia de la base productiva 'foodstore' (solo lectura).
    3. Inicia System.Diagnostics.Stopwatch inmediatamente antes de crear 'foodstore_restore_test'
       (ejecutando dropdb --if-exists previo para idempotencia y luego createdb).
    4. Ejecuta pg_restore --no-owner --no-privileges sobre 'foodstore_restore_test'.
    5. Ejecuta las 3 consultas de validacion minima (conteo de filas en categoria, cliente,
       producto, pedido, detalle_pedido; productos_invalidos = 0; detalles_invalidos = 0).
    6. Detiene el cronometro al finalizar las validaciones y guarda el reporte completo
       con RTO (en segundos y milisegundos) y RPO en evidencias/resultado_simulacro_rto_rpo.txt.
.NOTES
    SEGURIDAD Y PROTECCION:
    - Cero contrasenas expuestas: No contiene contrasenas ni variables de clave en texto plano.
      Autenticacion gestionada via %APPDATA%\postgresql\pgpass.conf o variables externas seguras.
    - Proteccion de produccion: La base 'foodstore' NO se elimina ni se modifica. Toda la
      restauracion se realiza exclusivamente sobre la base descartable 'foodstore_restore_test'.
    - Esquema real: En la tabla 'producto' (TP1_FoodStore/schema.sql), la columna de precio
      se denomina 'precio_actual' (adaptado respecto al ejemplo generico 'precio' de la consigna).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Push-Location $PSScriptRoot
try {
    # Resolver binarios de PostgreSQL 16+ si no estan en el PATH de la sesion
    if (-not (Get-Command pg_restore -ErrorAction SilentlyContinue)) {
        $pgBin = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin" -Directory -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending |
                 Select-Object -First 1
        if ($pgBin) {
            $env:Path = "$($pgBin.FullName);$env:Path"
        } else {
            Write-Error "No se encontraron los binarios de PostgreSQL (psql, createdb, dropdb, pg_restore)."
            exit 1
        }
    }

    $backupDir    = "backups"
    $evidenciaDir = "evidencias"
    if (-not (Test-Path -Path $evidenciaDir)) {
        New-Item -ItemType Directory -Path $evidenciaDir -Force | Out-Null
    }

    # 1. Buscar el ultimo archivo .dump en backups/ y calcular su antiguedad (RPO observado)
    $latestDump = Get-ChildItem -Path "$backupDir/*.dump" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    if (-not $latestDump) {
        Write-Error "No se encontro ningun archivo .dump en '$backupDir/'. Ejecute primero backup_foodstore.ps1."
        exit 1
    }

    $simulacroStart = Get-Date
    $rpoSpan        = $simulacroStart - $latestDump.LastWriteTime
    $rpoSeconds     = [Math]::Round($rpoSpan.TotalSeconds, 2)
    $rpoMinutes     = [Math]::Round($rpoSpan.TotalMinutes, 2)
    $rpoFormatted   = "{0:D2}h:{1:D2}m:{2:D2}s ({3} segundos / {4} minutos)" -f `
                      [int]$rpoSpan.TotalHours, $rpoSpan.Minutes, $rpoSpan.Seconds, $rpoSeconds, $rpoMinutes
    $dumpSizeMB     = [Math]::Round($latestDump.Length / 1MB, 2)

    Write-Host "=========================================================================="
    Write-Host "SIMULACRO DE RECUPERACION CONTRA RELOJ - FOOD STORE (PostgreSQL 16+)"
    Write-Host "=========================================================================="
    Write-Host ("Respaldo seleccionado : {0} ({1} MB)" -f $latestDump.Name, $dumpSizeMB)
    Write-Host ("Fecha del respaldo    : {0}" -f $latestDump.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss.fff"))
    Write-Host ("Inicio del simulacro  : {0}" -f $simulacroStart.ToString("yyyy-MM-dd HH:mm:ss.fff"))
    Write-Host ("RPO observado         : {0}" -f $rpoFormatted)
    Write-Host "Base destino prueba   : foodstore_restore_test (foodstore permanece intacta)"
    Write-Host "--------------------------------------------------------------------------"

    # Consulta de conteo de filas de las 5 tablas requeridas por la consigna
    $sqlConteo = @"
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;
"@

    # Obtener conteo de referencia en la base original 'foodstore' ANTES de iniciar el cronometro RTO
    $origCountsRaw = & psql -X -h localhost -p 5432 -U postgres -d foodstore -t -A -F "|" -c $sqlConteo
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error al consultar conteo de referencia en 'foodstore'."
        exit 1
    }
    $origCounts = @{}
    foreach ($line in ($origCountsRaw -split "`r?`n")) {
        if ($line -match "\|") {
            $parts = $line.Split("|")
            $origCounts[$parts[0].Trim()] = [int64]$parts[1].Trim()
        }
    }

    # Limpieza previa de cualquier ensayo anterior ANTES de iniciar el cronometro del simulacro
    & dropdb -h localhost -p 5432 -U postgres --if-exists foodstore_restore_test | Out-Null

    # =========================================================================
    # 2. INICIO DEL CRONOMETRO RTO (inmediatamente antes de crear la base)
    # =========================================================================
    $rtoStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Etapa A: Creacion de la base descartable foodstore_restore_test
    $swCreate = [System.Diagnostics.Stopwatch]::StartNew()
    & createdb -h localhost -p 5432 -U postgres foodstore_restore_test
    if ($LASTEXITCODE -ne 0) {
        $rtoStopwatch.Stop()
        Write-Error "Fallo al crear la base descartable 'foodstore_restore_test'."
        exit 1
    }
    $swCreate.Stop()

    # Etapa B: Restauracion con pg_restore --no-owner --no-privileges
    $swRestore = [System.Diagnostics.Stopwatch]::StartNew()
    $ErrorActionPreference = "Continue"
    $restoreOutput = & pg_restore -h localhost -p 5432 -U postgres -d foodstore_restore_test --no-owner --no-privileges "$($latestDump.FullName)" 2>&1
    $restoreExitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    $swRestore.Stop()

    if ($restoreExitCode -ne 0) {
        $rtoStopwatch.Stop()
        Write-Error "pg_restore finalizo con codigo de error $restoreExitCode : $restoreOutput"
        exit $restoreExitCode
    }

    # Etapa C: Ejecucion de las 3 consultas de validacion minima sobre foodstore_restore_test
    $swValidate = [System.Diagnostics.Stopwatch]::StartNew()

    # Validacion 1: Conteo de filas en categoria, cliente, producto, pedido, detalle_pedido
    $restCountsRaw = & psql -X -h localhost -p 5432 -U postgres -d foodstore_restore_test -t -A -F "|" -c $sqlConteo
    $tablaConteoVisual = & psql -X -h localhost -p 5432 -U postgres -d foodstore_restore_test -c $sqlConteo

    # Validacion 2: Control de productos invalidos (usando precio_actual del esquema real TP1_FoodStore/schema.sql)
    $sqlProdInvalidos = "SELECT COUNT(*) AS productos_invalidos FROM producto WHERE precio_actual < 0 OR stock < 0;"
    $prodInvalidosVal = (& psql -X -h localhost -p 5432 -U postgres -d foodstore_restore_test -t -A -c $sqlProdInvalidos).Trim()
    $tablaProdVisual  = & psql -X -h localhost -p 5432 -U postgres -d foodstore_restore_test -c $sqlProdInvalidos

    # Validacion 3: Control de detalles de pedido invalidos
    $sqlDetInvalidos = "SELECT COUNT(*) AS detalles_invalidos FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;"
    $detInvalidosVal = (& psql -X -h localhost -p 5432 -U postgres -d foodstore_restore_test -t -A -c $sqlDetInvalidos).Trim()
    $tablaDetVisual  = & psql -X -h localhost -p 5432 -U postgres -d foodstore_restore_test -c $sqlDetInvalidos

    $swValidate.Stop()

    # =========================================================================
    # 5. DETENCION DEL CRONOMETRO RTO (al finalizar las validaciones minimas)
    # =========================================================================
    $rtoStopwatch.Stop()

    # Procesar y comparar conteos entre foodstore y foodstore_restore_test
    $restCounts = @{}
    foreach ($line in ($restCountsRaw -split "`r?`n")) {
        if ($line -match "\|") {
            $parts = $line.Split("|")
            $restCounts[$parts[0].Trim()] = [int64]$parts[1].Trim()
        }
    }

    $allCountsMatch = $true
    $comparisonLines = New-Object System.Collections.Generic.List[string]
    $comparisonLines.Add(("{0,-18} | {1,14} | {2,22} | {3,-10}" -f "Tabla", "foodstore", "foodstore_restore_test", "Estado"))
    $comparisonLines.Add(("-" * 74))

    foreach ($tbl in @("categoria", "cliente", "producto", "pedido", "detalle_pedido")) {
        $cOrig = $origCounts[$tbl]
        $cRest = $restCounts[$tbl]
        $match = ($cOrig -eq $cRest)
        if (-not $match) { $allCountsMatch = $false }
        $statusStr = if ($match) { "OK (100%)" } else { "DIFERENCIA" }
        $comparisonLines.Add(("{0,-18} | {1,14} | {2,22} | {3,-10}" -f $tbl, $cOrig, $cRest, $statusStr))
    }

    $prodInvInt = [int64]$prodInvalidosVal
    $detInvInt  = [int64]$detInvalidosVal
    $simulacroExitoso = ($allCountsMatch -and ($prodInvInt -eq 0) -and ($detInvInt -eq 0))
    $resultadoGlobal  = if ($simulacroExitoso) { "APROBADO (Restauracion e integridad verificadas al 100%)" } else { "FALLIDO" }

    $rtoTotalSec    = [Math]::Round($rtoStopwatch.Elapsed.TotalSeconds, 3)
    $rtoTotalMs     = $rtoStopwatch.ElapsedMilliseconds
    $createSec      = [Math]::Round($swCreate.Elapsed.TotalSeconds, 3)
    $restoreSec     = [Math]::Round($swRestore.Elapsed.TotalSeconds, 3)
    $validateSec    = [Math]::Round($swValidate.Elapsed.TotalSeconds, 3)

    # Generar reporte de evidencia en evidencias/resultado_simulacro_rto_rpo.txt
    $reportPath = "$evidenciaDir/resultado_simulacro_rto_rpo.txt"
    $reportContent = @"
================================================================================
REPORTE DE SIMULACRO DE DESASTRE CONTRA RELOJ (Parte 4 - restore_test.ps1)
================================================================================
Proyecto             : Food Store (Base de Datos II - Unidad 6)
Motor de Base Datos  : PostgreSQL 16+ (instancia local localhost:5432)
Base Principal       : foodstore (INTACTA - No tocada durante el simulacro)
Base de Simulacro    : foodstore_restore_test (Creada y validada desde cero)
Fecha del Simulacro  : $($simulacroStart.ToString("yyyy-MM-dd HH:mm:ss.fff zzz"))

--------------------------------------------------------------------------------
1. METRICA RPO (Recovery Point Objective - Antiguedad del Respaldo)
--------------------------------------------------------------------------------
Archivo utilizado    : $($latestDump.Name)
Ruta relativa        : backups/$($latestDump.Name)
Tamano del respaldo  : $($latestDump.Length) bytes ($dumpSizeMB MB)
Fecha del respaldo   : $($latestDump.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss.fff"))
Inicio recuperacion  : $($simulacroStart.ToString("yyyy-MM-dd HH:mm:ss.fff"))
RPO Previsto (Meta)  : <= 24 horas (esquema de respaldo diario)
RPO Observado        : $rpoFormatted

--------------------------------------------------------------------------------
2. METRICA RTO (Recovery Time Objective - Tiempo Total de Recuperacion)
--------------------------------------------------------------------------------
RTO Previsto (Meta)  : <= 300 segundos (5 minutos para laboratorio local)
Desglose cronometrado (System.Diagnostics.Stopwatch):
  a) Creacion de base (createdb foodstore_restore_test) : $createSec s ($($swCreate.ElapsedMilliseconds) ms)
  b) Restauracion (pg_restore --no-owner --no-privileges): $restoreSec s ($($swRestore.ElapsedMilliseconds) ms)
  c) Ejecucion de las 3 validaciones minimas en SQL     : $validateSec s ($($swValidate.ElapsedMilliseconds) ms)
  ------------------------------------------------------------------------------
  RTO TOTAL OBSERVADO : $rtoTotalSec segundos ($rtoTotalMs ms)

--------------------------------------------------------------------------------
3. COMPARACION DE CONTEO DE FILAS (foodstore vs. foodstore_restore_test)
--------------------------------------------------------------------------------
$($comparisonLines -join "`r`n")

Salida directa de la Validacion 1 en foodstore_restore_test:
$($tablaConteoVisual -join "`r`n")

--------------------------------------------------------------------------------
4. CONTROLES DE INTEGRIDAD Y RESTRICCIONES LOGICAS
--------------------------------------------------------------------------------
Nota tecnica: En el esquema real del proyecto (TP1_FoodStore/schema.sql), la
columna de precio en la tabla 'producto' es 'precio_actual' (adaptado del
nombre generico 'precio' del enunciado).

Control A - Productos invalidos (precio_actual < 0 OR stock < 0):
  Valor esperado : 0
  Valor obtenido : $prodInvInt
$($tablaProdVisual -join "`r`n")

Control B - Detalles de pedido invalidos (cantidad <= 0 OR precio_unitario < 0):
  Valor esperado : 0
  Valor obtenido : $detInvInt
$($tablaDetVisual -join "`r`n")

--------------------------------------------------------------------------------
5. DICTAMEN FINAL DEL SIMULACRO
--------------------------------------------------------------------------------
Estado : $resultadoGlobal
================================================================================
"@

    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host $reportContent

    if (-not $simulacroExitoso) {
        exit 4
    }
    exit 0
}
finally {
    Pop-Location
}
