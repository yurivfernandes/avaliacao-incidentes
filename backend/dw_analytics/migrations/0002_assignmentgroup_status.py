# Generated by Django 4.2.10 on 2025-01-24 19:58

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('dw_analytics', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='assignmentgroup',
            name='status',
            field=models.BooleanField(default=True),
        ),
    ]
