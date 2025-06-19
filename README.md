# SolvIT - Django Ticketing System

A comprehensive IT support ticketing system built with Django, featuring multi-role user management, file uploads, real-time messaging, and WhatsApp integration capabilities.

## 🚀 Features

### Core Functionality
- **Multi-Role Authentication**: Customers, Agents, and Admins with role-based permissions
- **Ticket Management**: Create, assign, update, and resolve support tickets
- **Real-time Messaging**: Rich messaging system with file attachments
- **File Upload System**: Secure file handling with validation (5MB limit, multiple file types)
- **Internal Comments**: Agent-only internal notes for collaboration
- **Responsive UI**: Modern, mobile-friendly interface with SolvIT branding

### Advanced Features
- **File Validation**: Supports PDF, DOC, DOCX, JPG, JPEG, PNG, TXT files
- **WhatsApp Ready**: Database structure prepared for WhatsApp API integration
- **PostgreSQL Database**: Production-ready database with proper indexing
- **Docker Support**: Containerized deployment with Nginx
- **Admin Interface**: Django admin panel for system management

## 🛠 Technology Stack

- **Backend**: Django 5.2.1, Python 3.12
- **Database**: PostgreSQL
- **Frontend**: HTML5, CSS3, JavaScript, Bootstrap 5
- **File Storage**: Django FileField with local storage
- **Authentication**: Django's built-in auth with custom user model
- **Containerization**: Docker & Docker Compose
- **Web Server**: Nginx (production)

## 📋 Requirements

```
Django==5.2.1
psycopg2-binary==2.9.11
django-crispy-forms==2.3
crispy-bootstrap5==2024.2
Pillow==10.4.0
```

## 🚀 Quick Start

### Local Development

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd solvit-ticketing-system
```

2. **Create virtual environment**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies**
```bash
pip install -r requirements.txt
```

4. **Configure database**
```bash
# Update database settings in it_ticketing_system/settings.py
# Default configuration uses PostgreSQL
```

5. **Run migrations**
```bash
python manage.py migrate
```

6. **Create superuser**
```bash
python manage.py createsuperuser
```

7. **Create user groups**
```bash
python manage.py shell
>>> from django.contrib.auth.models import Group
>>> Group.objects.create(name='Customers')
>>> Group.objects.create(name='Agents')
>>> Group.objects.create(name='Admins')
>>> exit()
```

8. **Run development server**
```bash
python manage.py runserver
```

Visit `http://127.0.0.1:8000` to access the application.

### Docker Deployment

1. **Build and run with Docker Compose**
```bash
docker-compose up --build
```

2. **Run migrations in container**
```bash
docker-compose exec web python manage.py migrate
docker-compose exec web python manage.py createsuperuser
```

## 🎯 User Roles & Permissions

### Customers
- Create support tickets
- View their own tickets
- Add messages and file attachments
- Track ticket status and updates

### Agents
- View assigned tickets
- Respond to customer messages
- Add internal comments (not visible to customers)
- Update ticket status and priority
- Self-assign unassigned tickets

### Admins
- Full access to all tickets
- Assign tickets to agents
- Manage user accounts through Django admin
- View system-wide statistics

## 📁 Project Structure

```
solvit-ticketing-system/
├── it_ticketing_system/     # Django project settings
├── tickets/                 # Main application
│   ├── models.py           # Database models
│   ├── views.py            # Application logic
│   ├── forms.py            # Form definitions
│   ├── templates/          # HTML templates
│   └── migrations/         # Database migrations
├── static/                 # Static assets (CSS, JS, Images)
├── media/                  # User uploaded files
├── templates/              # Global templates
├── nginx/                  # Nginx configuration
├── requirements.txt        # Python dependencies
├── docker-compose.yml      # Docker configuration
└── manage.py              # Django management script
```

## 🔧 Configuration

### Database Settings
Update `it_ticketing_system/settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'your_database_name',
        'USER': 'your_username',
        'PASSWORD': 'your_password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

### File Upload Settings
```python
# Maximum file size (5MB)
MAX_UPLOAD_SIZE = 5242880

# Allowed file types
ALLOWED_FILE_TYPES = ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.txt']
```

## 🔐 Security Features

- CSRF protection on all forms
- File type and size validation
- Role-based access control
- SQL injection protection via Django ORM
- XSS protection in templates
- Secure file upload handling

## 🚀 Production Deployment

### Automated Ubuntu Server Deployment
The project includes a comprehensive deployment script for Ubuntu servers:

```bash
# Make the deployment script executable
chmod +x deploy-ubuntu-server.sh

# Run the interactive deployment
./deploy-ubuntu-server.sh
```

The deployment script will:
- Install all required dependencies (Python, PostgreSQL, Nginx)
- Set up virtual environment and install Python packages
- Configure PostgreSQL database with secure credentials
- Set up systemd service for automatic startup
- Configure static files serving with WhiteNoise
- Apply Jazzmin admin theme
- Create Django superuser account

### Environment Variables
Create a `.env` file:
```
DEBUG=False
SECRET_KEY=your-secret-key
DATABASE_URL=postgresql://user:password@host:port/dbname
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
```

### Static Files
```bash
python manage.py collectstatic --noinput
```

### Database Backup
```bash
pg_dump your_database > backup.sql
```

## 🗑️ System Uninstallation

### Complete System Removal
The project includes a comprehensive uninstall script for complete system removal:

```bash
# Make the uninstall script executable
chmod +x uninstall-solvit-ticketing.sh

# Run the interactive uninstall (IRREVERSIBLE!)
./uninstall-solvit-ticketing.sh
```

⚠️ **WARNING**: The uninstall process is irreversible and will remove:
- All application files and code
- PostgreSQL database and all ticket data
- System service configurations
- Static files and media uploads

### Pre-Uninstall Backup
Always backup your data before uninstalling:

```bash
# Backup database
sudo -u postgres pg_dump test2 > solvit_backup_$(date +%Y%m%d).sql

# Backup media files
sudo cp -r /opt/solvit-ticketing/media ~/solvit_media_backup
```

For detailed uninstall instructions, see [UNINSTALL_README.md](UNINSTALL_README.md).

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Documentation & Troubleshooting

- [Deployment Options](DEPLOYMENT_OPTIONS.md) - Different ways to deploy the system
- [Manual Deployment Guide](MANUAL_DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [Nginx Proxy Manager Guide](NGINX_PROXY_MANAGER_GUIDE.md) - Setting up with NPM
- [Preventing Connection Issues](PREVENTING_CONNECTION_ISSUES.md) - How to avoid common connection problems
- [Troubleshooting CSRF](TROUBLESHOOTING_CSRF.md) - Resolving CSRF verification failures
- [Admin Theming Guide](ADMIN_THEMING_GUIDE.md) - Customizing the admin panel

## 🆘 Support

For support and questions:
- Create an issue in this repository
- Contact: [your-email@domain.com]

## 🔮 Future Enhancements

- [ ] WhatsApp Business API integration
- [ ] Real-time notifications with WebSockets
- [ ] Mobile application (React Native/Flutter)
- [ ] Advanced reporting and analytics
- [ ] Email notifications
- [ ] Knowledge base integration
- [ ] Multi-language support
- [ ] API endpoints for third-party integrations

## 🏆 Acknowledgments

- Django Framework for the robust backend
- Bootstrap for responsive UI components
- PostgreSQL for reliable data storage
- Docker for containerization support

---

**Built with ❤️ for efficient IT support management**
