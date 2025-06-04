from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django import forms
from django.contrib.auth.forms import AuthenticationForm
from django.db.models.signals import post_save # For automatically creating/updating Profile
from django.dispatch import receiver           # For automatically creating/updating Profile


class Ticket(models.Model):
    STATUS_CHOICES = [
        ('OPEN', 'Open'),
        ('IN_PROGRESS', 'In Progress'),
        ('RESOLVED', 'Resolved'),
        ('CLOSED', 'Closed'),
    ]

    PRIORITY_CHOICES = [ # Adding basic priority early is good
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('URGENT', 'Urgent'),
    ]

    title = models.CharField(max_length=200)
    description = models.TextField()
    customer = models.ForeignKey(User, related_name='created_tickets', on_delete=models.CASCADE)
    agent = models.ForeignKey(User, related_name='assigned_tickets', on_delete=models.SET_NULL, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='OPEN')
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='MEDIUM')
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.id} - {self.title}"

class Message(models.Model):
    ticket = models.ForeignKey(Ticket, related_name='messages', on_delete=models.CASCADE)
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.TextField()
    timestamp = models.DateTimeField(default=timezone.now)
    # is_internal_note = models.BooleanField(default=False) # For Phase 2/3

    def __str__(self):
        return f"Message by {self.sender.username} on Ticket {self.ticket.id}"


class CustomLoginForm(AuthenticationForm):
    remember_me = forms.BooleanField(
        required=False,
        initial=True,  # Set to True to have it checked by default, or False to be unchecked
        widget=forms.CheckboxInput(attrs={'class': 'form-check-input', 'id': 'rememberMeInput'}),
        label="Remember Me" # This label will be used if you render {{ form.remember_me.label_tag }}
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # You can customize widget attributes for username and password here if needed
        self.fields['username'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Username or Email'}
        )
        self.fields['password'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Password'}
        )

class Profile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )
    mobile = models.CharField(
        max_length=20,
        unique=True,
        blank=False,
        null=False,
        help_text="Required. Your unique mobile number."
    )
    # You can add other fields here later, like avatar, address, etc.

    def __str__(self):
        return f'{self.user.username} Profile'


# Signal to create or update the user profile automatically whenever a User instance is saved.
@receiver(post_save, sender=User)
def create_or_update_user_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)