# tickets/models.py
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone
from django.conf import settings

class CustomUserManager(BaseUserManager):
    def create_user(self, mobile, password=None, **extra_fields):
        """
        Creates and saves a User with the given mobile (USERNAME_FIELD), password,
        and other fields.
        """
        if not mobile:
            raise ValueError('The Mobile (USERNAME_FIELD) must be set')

        # Username field (if it exists on the model for other purposes)
        # needs to be handled. Let's assume it should also be unique
        # and try to populate it from an extra_field or default it.
        # If 'username' is in extra_fields, use it. Otherwise, what should it be?
        # For now, let's assume 'username' is passed in extra_fields if needed.
        username = extra_fields.pop('username', None) # Expect 'username' to be passed if needed
        if not username: # If you absolutely need a username field to be populated
             # You could default it to mobile, but ensure it's unique if the field requires it.
             # This can be tricky if 'username' has its own unique constraint.
             # For now, let's require it to be passed if it exists and is needed.
             pass # Or raise ValueError('Username must be provided if the model has a username field')

        email = extra_fields.pop('email', None)
        if email:
            email = self.normalize_email(email)
        
        first_name = extra_fields.pop('first_name', '')
        last_name = extra_fields.pop('last_name', '')

        user = self.model(
            mobile=mobile,        # This is the USERNAME_FIELD
            username=username,    # Populate the separate username field
            email=email,
            first_name=first_name,
            last_name=last_name,
            **extra_fields
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, mobile, username, email, password=None, **extra_fields):
        """
        Creates and saves a superuser. 'mobile' is the USERNAME_FIELD.
        'username' is the separate username field.
        'email' is also required for superusers.
        """
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')
        if not email:
            raise ValueError('Superuser must have an email address.')
        if not username: # If the model has a mandatory username field
            raise ValueError('Superuser must have a username.')


        # When USERNAME_FIELD is 'mobile', createsuperuser will prompt for 'mobile'.
        # 'username' and 'email' are in REQUIRED_FIELDS.
        return self.create_user(mobile=mobile, password=password, username=username, email=email, **extra_fields)

class CustomUser(AbstractBaseUser, PermissionsMixin):
    # The 'username' field:
    # If mobile is USERNAME_FIELD, do you still need a separate, unique 'username'?
    # If yes, it needs to be populated. If no, you could remove it,
    # but AbstractBaseUser expects a field named by USERNAME_FIELD.
    # Let's keep 'username' for now but it must be populated.
    username = models.CharField(max_length=150, unique=True, help_text="A unique username for the system (can be different from mobile/email).")
    
    email = models.EmailField(blank=True, null=True, unique=True, help_text="Optional. If provided, must be unique.")
    first_name = models.CharField(max_length=150, blank=True)
    last_name = models.CharField(max_length=150, blank=True)
    
    # Mobile is the login identifier
    mobile = models.CharField(max_length=20, unique=True, help_text="Required. Used for login.")

    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(default=timezone.now)

    objects = CustomUserManager()

    USERNAME_FIELD = 'mobile'
    # Since 'mobile' is USERNAME_FIELD, 'username' (if you keep it) and 'email'
    # become candidates for REQUIRED_FIELDS for the 'createsuperuser' command.
    REQUIRED_FIELDS = ['username', 'email']

    def __str__(self):
        if self.first_name and self.last_name:
            return f"{self.first_name} {self.last_name}"
        elif self.username != self.mobile:  # If username is different from mobile
            return self.username
        return self.mobile  # Fallback to mobile if no other identifiers are available

    def get_full_name(self):
        """Return the first_name plus the last_name, with a space in between."""
        full_name = f"{self.first_name} {self.last_name}"
        return full_name.strip()

    def get_short_name(self):
        """Return the short name for the user."""
        return self.first_name

    groups = models.ManyToManyField(
        'auth.Group',
        verbose_name='groups',
        blank=True,
        related_name="customuser_group_set", # Changed related_name
        related_query_name="customuser_group",
    )
    user_permissions = models.ManyToManyField(
        'auth.Permission',
        verbose_name='user permissions',
        blank=True,
        related_name="customuser_permission_set", # Changed related_name
        related_query_name="customuser_permission",
    )

# --- Ticket Model ---
class Ticket(models.Model):
    # ... (no changes needed if using settings.AUTH_USER_MODEL) ...
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='created_tickets', on_delete=models.CASCADE)
    agent = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='assigned_tickets', null=True, blank=True, on_delete=models.SET_NULL)
    # ...
    title = models.CharField(max_length=200)
    description = models.TextField()
    STATUS_CHOICES = [
        ('OPEN', 'Open'),
        ('IN_PROGRESS', 'In Progress'),
        ('RESOLVED', 'Resolved'),
        ('CLOSED', 'Closed'),
    ]
    PRIORITY_CHOICES = [
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('URGENT', 'Urgent'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='OPEN')
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='MEDIUM')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Ticket #{self.id} - {self.title}"


# --- Message Model ---
class Message(models.Model):
    # ... (no changes needed if using settings.AUTH_USER_MODEL) ...
    ticket = models.ForeignKey(Ticket, related_name='messages', on_delete=models.CASCADE)
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='sent_messages', on_delete=models.CASCADE)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        # Use mobile (USERNAME_FIELD) or username for display
        sender_identifier = self.sender.mobile if hasattr(self.sender, 'mobile') else self.sender.username
        return f"Message by {sender_identifier} on Ticket #{self.ticket.id} at {self.timestamp}"