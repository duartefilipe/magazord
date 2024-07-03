import boto3
import subprocess
from datetime import datetime
import os

# Configurações do S3
s3 = boto3.client(
    's3',
    aws_access_key_id='ACCESS_KEY_ID',
    aws_secret_access_key='SECRET_ACCESS_KEY'
)
bucket_name = 'postgres-backups-bucket1'
backup_file = '/tmp/testdb_backup_{}.sql'.format(datetime.now().strftime("%Y%m%d%H%M%S"))

# Configuração da senha do PostgreSQL
os.environ['PGPASSWORD'] = 'postgres'

# Verificar se o banco de dados existe
try:
    subprocess.run(['psql', '-U', 'postgres', '-h', 'localhost', '-c', 'SELECT 1 FROM pg_database WHERE datname=\'testdb\''], check=True)
    db_exists = True
except subprocess.CalledProcessError:
    db_exists = False

if not db_exists:
    print('O banco de dados "testdb" não existe. Por favor, crie o banco de dados e tente novamente.')
else:
    # Dump do banco de dados
    try:
        subprocess.run(['pg_dump', '-U', 'postgres', '-h', 'localhost', 'testdb', '-f', backup_file], check=True)
        print('Backup {} criado com sucesso.'.format(backup_file))
    except subprocess.CalledProcessError as e:
        print('Erro ao criar o backup: {}'.format(e))

    # Verifica se o arquivo de backup foi criado corretamente
    if os.path.exists(backup_file):
        # Upload para o S3
        try:
            s3.upload_file(backup_file, bucket_name, backup_file)
            print('Backup {} enviado para o bucket {}'.format(backup_file, bucket_name))
        except Exception as e:
            print('Erro ao enviar o backup para o S3: {}'.format(e))
    else:
        print('Falha ao criar o arquivo de backup: {}'.format(backup_file))
