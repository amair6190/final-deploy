import os
from pathlib import Path
from django.urls import reverse_lazy

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'django-insecure-7k0-_x+ww%ipnma6^kqe(tf@-nxkm1!%9kaea55qwj9842=os4'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = []



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
        'HOST': 'localhost',
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

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = 'static/'
LOGIN_URL = 'tickets:login'

# Default primary key field type
# https://docs.djangoproject.com/en/5.2/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'



STATIC_URL = '/static/'
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

LOGIN_REDIRECT_URL = 'tickets:agent_dashboard' # Correct setting for agents
LOGIN_REDIRECT_URL = 'tickets:customer_dashboard' # Or simply '/' if you prefer
LOGOUT_REDIRECT_URL = reverse_lazy('home') # Good to set this too

CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5" # Or "bootstrap4" if you used that
CRISPY_TEMPLATE_PACK = "bootstrap5" 

# Default session age (e.g., expires when browser closes or after a shorter period)
SESSION_COOKIE_AGE = 60 * 60 * 24 * 1  # 1 day (default is 2 weeks, adjust as needed for non-remembered sessions)
# Set SESSION_EXPIRE_AT_BROWSER_CLOSE to False if you want SESSION_COOKIE_AGE to be the primary determinant
SESSION_EXPIRE_AT_BROWSER_CLOSE = False # Set to True if you want sessions to clear on browser close by default

# "Remember Me" session age (e.g., 30 days)
SESSION_COOKIE_AGE_REMEMBER_ME = 60 * 60 * 24 * 30  # 30 days in seconds