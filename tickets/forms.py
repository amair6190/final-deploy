from django import forms
from .models import Ticket, Message
from django.contrib.auth.forms import AuthenticationForm, UserCreationForm # Add UserCreationForm
from django.contrib.auth.models import User # Assuming default User model
from .models import User, Profile # Add Profile

class TicketCreationForm(forms.ModelForm):
    class Meta:
        model = Ticket
        fields = ['title', 'description', 'priority'] # Customer sets these initially
        # Customer and status are set programmatically

class MessageCreationForm(forms.ModelForm):
    class Meta:
        model = Message
        fields = ['content']
        widgets = {
            'content': forms.Textarea(attrs={'rows': 3, 'placeholder': 'Type your message...'}),
        }
        # Ticket and sender are set programmatically

class TicketUpdateForm(forms.ModelForm): # For agents
    class Meta:
        model = Ticket
        fields = ['status', 'priority'] # Agent might also re-assign later


class CustomLoginForm(AuthenticationForm): # <--- CHECK THIS NAME CAREFULLY
    remember_me = forms.BooleanField(
        required=False,
        initial=True,
        widget=forms.CheckboxInput(attrs={'class': 'form-check-input', 'id': 'rememberMeInput'}),
        label="Remember Me"
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['username'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Username or Email'}
        )
        self.fields['password'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Password'}
        )

class CustomerRegistrationForm(UserCreationForm):
    mobile = forms.CharField(
        required=True,
        label='Mobile Number',
        help_text='Required. Your unique mobile number for identification.',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'e.g. +1234567890'
        }),
        error_messages={
            'required': 'Mobile number is required for registration',
            'unique': 'This mobile number is already registered'
        }
    )

    email = forms.EmailField(
        required=False,  # Changed to False to make it optional
        help_text='Optional. A valid email address.',  # Updated help text
        widget=forms.EmailInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'your@email.com (optional)'
        })
    )

    first_name = forms.CharField(
        required=False,
        label='First name',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'First Name'
        })
    )

    last_name = forms.CharField(
        required=False,
        label='Last name',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'Last Name'
        })
    )

    class Meta(UserCreationForm.Meta):
        model = User
        fields = UserCreationForm.Meta.fields + ('first_name', 'last_name', 'email')

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['username'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Choose a username'}
        )
        self.fields['username'].help_text = 'Required. 150 characters or fewer. Letters, digits and @/./+/-/_ only.'
        self.fields['password1'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Enter password'}
        )
        self.fields['password2'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Confirm password'}
        )

    def clean_email(self):
        email = self.cleaned_data.get('email')
        if email and User.objects.filter(email__iexact=email).exists():
            raise forms.ValidationError("This email address is already in use. Please use a different one.")
        return email

    def clean_mobile(self):
        mobile = self.cleaned_data.get('mobile')
        if not mobile: # If mobile is required, this check might be redundant due to field's required=True
            raise forms.ValidationError("Mobile number is required.") 
        
        # Check for uniqueness directly on the Profile model
        if Profile.objects.filter(mobile=mobile).exists():
            # Check if this mobile number belongs to the user being edited (if editing later)
            # For registration, any existing mobile is an issue.
            # if not self.instance or not hasattr(self.instance, 'profile') or self.instance.profile.mobile != mobile:
            raise forms.ValidationError("This mobile number is already registered.")
        return mobile

    def save(self, commit=True):
        user = super().save(commit=False) # Create User instance but don't save to DB yet

        # first_name, last_name, email are handled by super().save()
        # because they are in Meta.fields and User model has them.
        
        if commit:
            user.save() # Save the User instance to the database

            # Profile instance should be created by the post_save signal now.
            # Or, if you prefer to be explicit or don't use signals:
            # profile, created = Profile.objects.get_or_create(user=user)
            
            # It's safer to fetch the profile explicitly or ensure it exists
            try:
                profile = user.profile # Access the related profile
            except Profile.DoesNotExist: 
                # This should not happen if the signal worked or if you created it above
                profile = Profile.objects.create(user=user)
            
            profile.mobile = self.cleaned_data.get('mobile')
            profile.save()
        return user