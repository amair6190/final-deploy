# tickets/forms.py

import os
from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm # Ensure AuthenticationForm is also imported
from django.core.exceptions import ValidationError # Import ValidationError
from .models import Ticket, Message, InternalComment
from django.contrib.auth.models import Group

CustomUser = get_user_model()

class CustomLoginForm(AuthenticationForm):
    # When USERNAME_FIELD is 'mobile', the 'username' field in AuthenticationForm
    # will be used for the mobile number input.
    # No 'remember_me' was in your screenshot for login, but keeping it from before.
    remember_me = forms.BooleanField(
        required=False,
        initial=True,
        widget=forms.CheckboxInput(attrs={'class': 'form-check-input', 'id': 'rememberMeInput'}),
        label="Remember Me"
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['username'].label = "Mobile/Email" # Change label
        self.fields['username'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Mobile OR Email'}
        )
        self.fields['password'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Password'}
        )

class CustomerRegistrationForm(UserCreationForm):
    # Since CustomUser.USERNAME_FIELD = 'mobile', UserCreationForm will adapt.
    # Its internal 'username' field effectively becomes the 'mobile' field.
    # We need to ensure our 'mobile' field definition overrides/matches this.
    # And we need to provide data for the actual 'CustomUser.username' field.

    # This field will be used by UserCreationForm as the USERNAME_FIELD input
    mobile = forms.CharField( # This name must match CustomUser.USERNAME_FIELD or be 'username'
        required=True,
        label='Mobile Number', # This is what the user sees
        help_text='Required. Your unique mobile number for identification and login.',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'e.g. 8454938270', # Example
            'type': 'tel' 
        }),
        error_messages={
            'required': 'Mobile number is required.',
            'unique': 'This mobile number is already registered.'
        }
    )
    
    # The separate 'username' field on the CustomUser model.
    # Since it's not on the form, we'll handle it in save() or it will be
    # defaulted by the manager. The manager now defaults it to 'mobile'.
    # So, no explicit 'username' field needed here for form rendering.

    email = forms.EmailField(
        required=False,
        label='Email Address',
        help_text='Optional. If provided, it must be a unique valid email address.',
        widget=forms.EmailInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'your@email.com (optional)'
        }),
        error_messages={'unique': 'This email address is already in use.'}
    )

    first_name = forms.CharField(
        required=True,
        label='First Name',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'First Name'
        })
    )

    last_name = forms.CharField(
        required=True,
        label='Last Name',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'Last Name'
        })
    )

    class Meta(UserCreationForm.Meta):
        model = CustomUser
        # When USERNAME_FIELD = 'mobile', UserCreationForm expects 'mobile' to be the primary identifier field.
        # The fields listed here are for data collection.
        # 'password1' and 'password2' are handled by UserCreationForm itself.
        # The 'username' field of UserCreationForm is now effectively mapped to 'mobile'.
        # We list 'mobile' so we can customize its widget/label.
        # We list other fields we want to collect.
        # The actual `CustomUser.username` field will be populated by our manager.
        fields = ('mobile', 'first_name', 'last_name', 'email')

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # UserCreationForm's 'username' field is now for 'mobile'
        if 'username' in self.fields: # 'username' is the default name UserCreationForm uses for USERNAME_FIELD
            self.fields['username'].label = "Mobile Number"
            self.fields['username'].help_text = "Required. Used for login."
            self.fields['username'].widget.attrs.update({
                'class': 'form-control-themed', 
                'placeholder': 'e.g. 8454938270'
            })
            # If you want to ensure our explicitly defined 'mobile' field is used:
            # del self.fields['username'] # Risky with UserCreationForm
            # For UserCreationForm when USERNAME_FIELD is not 'username',
            # it's often easier to let it manage its 'username' field and map it
            # in the save method or ensure your USERNAME_FIELD is named 'username' in the form.

            # To be absolutely clear and control our 'mobile' field:
            # It seems UserCreationForm will create a field named self.Meta.model._meta.USERNAME_FIELD
            # So if USERNAME_FIELD is 'mobile', it will have a self.fields['mobile'] already.
            # Our explicit 'mobile' definition above should override its default widget/label.


        self.fields['password1'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Enter password'}
        )
        self.fields['password1'].label = 'Password'
        self.fields['password2'].widget.attrs.update(
            {'class': 'form-control-themed', 'placeholder': 'Confirm password'}
        )
        self.fields['password2'].label = 'Confirm Password'

    # clean_email and clean_mobile as before, they will check CustomUser for uniqueness.
    def clean_email(self):
        email = self.cleaned_data.get('email')
        # Convert empty string to None to handle unique constraint properly
        if not email:  # This covers both empty string and None
            return None
        
        # Only check uniqueness if email is provided
        query = CustomUser.objects.filter(email__iexact=email)
        if self.instance and self.instance.pk: 
            query = query.exclude(pk=self.instance.pk)
        if query.exists(): 
            raise ValidationError(self.fields['email'].error_messages['unique'])
        return email

    def clean_mobile(self):
        # This method will be called for the field named 'mobile' in the form.
        # Since 'mobile' is also USERNAME_FIELD, UserCreationForm's unique check
        # for USERNAME_FIELD will also apply. This provides an earlier check.
        mobile = self.cleaned_data.get('mobile')
        if mobile:
            query = CustomUser.objects.filter(mobile=mobile)
            if self.instance and self.instance.pk: query = query.exclude(pk=self.instance.pk)
            if query.exists(): raise ValidationError(self.fields['mobile'].error_messages['unique'])
        return mobile
        
    def save(self, commit=True):
        # Override save to ensure proper user creation through our custom manager
        user = super().save(commit=False)
        
        # The UserCreationForm might not properly set username, so let's ensure it's set
        if not user.username:
            # Generate a unique username based on mobile
            username = f"user_{user.mobile}"
            counter = 1
            original_username = username
            while CustomUser.objects.filter(username=username).exists():
                username = f"{original_username}_{counter}"
                counter += 1
            user.username = username
        
        # Handle email properly (convert empty string to None)
        if hasattr(user, 'email') and user.email == '':
            user.email = None
            
        if commit:
            user.save()
        return user

# --- Other forms ---
class TicketCreationForm(forms.ModelForm):  # ... as before ...
    class Meta:
        model = Ticket
        fields = ['title', 'description', 'priority']

class MessageCreationForm(forms.ModelForm):
    class Meta:
        model = Message
        fields = ['content', 'attachment', 'via_whatsapp']
        widgets = {
            'content': forms.Textarea(attrs={'rows': 3, 'placeholder': 'Type your message...'}),
            'attachment': forms.FileInput(attrs={'class': 'form-control'}),
            'via_whatsapp': forms.HiddenInput()
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.initial['via_whatsapp'] = False  # Default to False

    def clean_attachment(self):
        attachment = self.cleaned_data.get('attachment')
        if attachment:
            # 5 MB limit
            if attachment.size > 5 * 1024 * 1024:
                raise forms.ValidationError("File size must be under 5MB")
            # Validate file extension - add or remove extensions as needed
            valid_extensions = ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.txt']
            ext = os.path.splitext(attachment.name)[1]
            if ext.lower() not in valid_extensions:
                raise forms.ValidationError("Unsupported file type. Allowed types: PDF, DOC, DOCX, JPG, PNG, TXT")
        return attachment

class TicketUpdateForm(forms.ModelForm):
    class Meta:
        model = Ticket
        fields = ['status', 'priority', 'agent']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Filter agent choices to only show users in the Agents group
        agents_group = Group.objects.get(name='Agents')
        self.fields['agent'].queryset = CustomUser.objects.filter(groups=agents_group)
        self.fields['agent'].label = "Assign to Agent"
        
        # Add Bootstrap classes
        for field in self.fields:
            self.fields[field].widget.attrs.update({'class': 'form-control'})

class InternalCommentForm(forms.ModelForm):
    class Meta:
        model = InternalComment
        fields = ['content']
        widgets = {
            'content': forms.Textarea(attrs={
                'rows': 3, 
                'placeholder': 'Add an internal note (only visible to agents)',
                'class': 'form-control'
            })
        }