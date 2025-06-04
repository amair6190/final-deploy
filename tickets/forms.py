# tickets/forms.py

from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm # Ensure AuthenticationForm is also imported
from django.core.exceptions import ValidationError # Import ValidationError
from .models import Ticket, Message

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
        required=False,
        label='First Name',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'First Name (Optional)'
        })
    )

    last_name = forms.CharField(
        required=False,
        label='Last Name',
        widget=forms.TextInput(attrs={
            'class': 'form-control-themed',
            'placeholder': 'Last Name (Optional)'
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
        if email:
            query = CustomUser.objects.filter(email__iexact=email)
            if self.instance and self.instance.pk: query = query.exclude(pk=self.instance.pk)
            if query.exists(): raise ValidationError(self.fields['email'].error_messages['unique'])
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
        
    # No save() override needed here. UserCreationForm's save() will call
    # CustomUserManager.create_user(mobile=cleaned_data['mobile'], password=..., 
    #                                first_name=cleaned_data['first_name'], etc.)
    # The manager will then set CustomUser.username to mobile by default.

# --- Other forms ---
class TicketCreationForm(forms.ModelForm):  # ... as before ...
    class Meta:
        model = Ticket
        fields = ['title', 'description', 'priority']

class MessageCreationForm(forms.ModelForm):  # ... as before ...
    class Meta:
        model = Message
        fields = ['content']
        widgets = {
            'content': forms.Textarea(attrs={'rows': 3, 'placeholder': 'Type your message...'})
        }

class TicketUpdateForm(forms.ModelForm):  # ... as before ...
    class Meta:
        model = Ticket
        fields = ['status', 'priority']