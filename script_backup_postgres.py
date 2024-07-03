# -*- coding: utf-8 -*-

import boto3
import subprocess
from datetime import datetime
import os

# Configurações do S3
s3 = boto3.client('s3')
bucket_name = 'postgres-backups-bucket1'
backup_file = f'/tmp/testdb_backup_{datetime.now().strftime("%Y%m%d%H%M%S")}.sql'

# Configuração da senha do PostgreSQL
os.environ['PGPASSWORD'] = 'postgres'

# Dump do banco de dados
try:
    subprocess.run(['pg_dump', '-U', 'postgres', '-h', 'localhost', 'testdb', '-f', backup_file], check=True)
    print(f'Backup {backup_file} criado com sucesso.')
except subprocess.CalledProcessError as e:
    print(f'Erro ao criar o backup: {e}')

# Verifica se o arquivo de backup foi criado corretamente
if os.path.exists(backup_file):
    # Upload para o S3
    try:
        s3.upload_file(backup_file, bucket_name, backup_file)
        print(f'Backup {backup_file} enviado para o bucket {bucket_name}')
    except Exception as e:
        print(f'Erro ao enviar o backup para o S3: {e}')
else:
    print(f'Falha ao criar o arquivo de backup: {backup_file}')
