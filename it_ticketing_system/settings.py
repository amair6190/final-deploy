import os
from pathlib import Path
from django.urls import reverse_lazy

# it_ticketing_system/settings.py
AUTH_USER_MODEL = 'tickets.CustomUser' # app_name.ModelName

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'django-insecure-7k0-_x+ww%ipnma6^kqe(tf@-nxkm1!%9kaea55qwj9842=os4'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = []


AUTHENTICATION_BACKENDS = [
    'tickets.backends.MobileOrEmailBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'tickets',
    'crispy_forms',
    "crispy_bootstrap5",
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'it_ticketing_system.urls'

TEMPLATES = [
    {
       'BACKEND': 'django.template.backends.django.DjangoTemplates',
       'DIRS': [os.path.join(BASE_DIR, 'templates')], # Project-level templates
        'APP_DIRS': True, # This allows Django to find app-specific templates like tickets/templates/tickets/login.html
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'tickets.context_processors.user_groups', # If you create this for user group info in all templates
            ],
        },
    },
]


WSGI_APPLICATION = 'it_ticketing_system.wsgi.application'


# Database
# https://docs.djangoproject.com/en/5.2/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'it_ticketing_db',
        'USER': 'amair',
        'PASSWORD': 'Psql@solvit@2025',
        'HOST': '10.0.0.6',
        'PORT': '5432',
    }
}


# Password validation
# https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.2/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'Asia/Kolkata'

USE_I18N = True

USE_TZ = True

# Add custom datetime format settings
DATETIME_FORMAT = 'Y-m-d g:i A'  # 12-hour format with AM/PM
DATE_FORMAT = 'Y-m-d'
TIME_FORMAT = 'g:i A'  # 12-hour format with AM/PM


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = '/static/'
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Media files (Uploads)
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# File Upload Settings
MAX_UPLOAD_SIZE = 5242880  # 5MB in bytes

# Login and Authentication Settings
LOGIN_URL = 'tickets:login'
LOGIN_REDIRECT_URL = 'tickets:customer_dashboard'  # For customers
LOGOUT_REDIRECT_URL = reverse_lazy('home')

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Crispy Forms Settings
CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5"
CRISPY_TEMPLATE_PACK = "bootstrap5"

# Session Settings
SESSION_COOKIE_AGE = 60 * 60 * 24 * 1  # 1 day
SESSION_EXPIRE_AT_BROWSER_CLOSE = False
SESSION_COOKIE_AGE_REMEMBER_ME = 60 * 60 * 24 * 30  # 30 days