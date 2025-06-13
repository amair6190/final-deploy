# tickets/models.py
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone
from django.conf import settings
import os

class CustomUserManager(BaseUserManager):
    def create_user(self, mobile, password=None, **extra_fields):
        """
        Creates and saves a User with the given mobile (USERNAME_FIELD), password,
        and other fields.
        """
        if not mobile:
            raise ValueError('The Mobile (USERNAME_FIELD) must be set')

        # Handle username field - if not provided, generate a unique one based on mobile
        username = extra_fields.pop('username', None)
        if not username:
            # Generate a unique username based on mobile
            username = f"user_{mobile}"
            # Ensure uniqueness by adding a counter if needed
            counter = 1
            original_username = username
            while self.model.objects.filter(username=username).exists():
                username = f"{original_username}_{counter}"
                counter += 1

        email = extra_fields.pop('email', None)
        if email:
            email = self.normalize_email(email)
        # Convert empty string to None for unique constraint
        if email == '':
            email = None
        
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

        # Pass username explicitly to create_user
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
    ticket = models.ForeignKey(Ticket, related_name='messages', on_delete=models.CASCADE)
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='sent_messages', on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    attachment = models.FileField(upload_to='message_attachments/', null=True, blank=True)
    via_whatsapp = models.BooleanField(default=False)

    def __str__(self):
        sender_identifier = self.sender.mobile if hasattr(self.sender, 'mobile') else self.sender.username
        return f"Message by {sender_identifier} on Ticket #{self.ticket.id} at {self.created_at}"

    class Meta:
        ordering = ['created_at']

# --- TicketAttachment Model ---
class TicketAttachment(models.Model):
    ticket = models.ForeignKey(Ticket, related_name='attachments', on_delete=models.CASCADE)
    file = models.FileField(upload_to='ticket_attachments/')
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='uploaded_attachments', on_delete=models.CASCADE)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    description = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return f"Attachment {self.file.name} for Ticket #{self.ticket.id}"

    def filename(self):
        return os.path.basename(self.file.name)

    class Meta:
        ordering = ['-uploaded_at']

# --- InternalComment Model ---
class InternalComment(models.Model):
    ticket = models.ForeignKey(Ticket, related_name='internal_comments', on_delete=models.CASCADE)
    author = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='internal_comments', on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Internal comment by {self.author.username} on Ticket #{self.ticket.id}"

    class Meta:
        ordering = ['created_at']