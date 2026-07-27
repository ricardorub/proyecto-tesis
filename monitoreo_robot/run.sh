#!/bin/bash

# run.sh - Automatización de arranque para monitoreo_robot

# Obtener directorio del script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

echo "=============================================="
echo "      Rover Cam - Servidor de Monitoreo       "
echo "=============================================="

# 1. Crear entorno virtual si no existe
if [ ! -d "env" ]; then
    echo "Creating virtual environment in 'env' directory..."
    python3 -m venv env
    if [ $? -ne 0 ]; then
        echo "Error: Fallo al crear el entorno virtual. Asegurate de tener python3-venv instalado."
        exit 1
    fi
fi

# 2. Activar entorno virtual
echo "Activating virtual environment..."
source env/bin/activate

# 3. Actualizar pip e instalar dependencias
echo "Checking and installing dependencies from requirements.txt..."
pip install --upgrade pip
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "Error: Fallo al instalar las dependencias."
    exit 1
fi

# 4. Lanzar servidor FastAPI con Uvicorn
echo "Iniciando servidor de video y control en http://localhost:5000"
echo "Presiona Ctrl+C para detener el servidor."
echo "=============================================="

export PYTHONUNBUFFERED=1
uvicorn app:app --host 0.0.0.0 --port 5000
