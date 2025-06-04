# tickets/backends.py
from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model
from django.db.models import Q

UserModel = get_user_model()

class MobileOrEmailBackend(ModelBackend):
    def authenticate(self, request, username=None, password=None, **kwargs):
        # 'username' parameter here is what the user typed into the login form's
        # primary input field (which for CustomLoginForm is labeled "Mobile Number").
        identifier = username 

        if identifier is None: 
            # This case might happen if authenticate is called programmatically without 'username'
            # For standard form login, 'username' should be populated from the form field.
            # UserModel.USERNAME_FIELD is 'mobile' in your CustomUser model.
            identifier = kwargs.get(UserModel.USERNAME_FIELD) 
        
        if not identifier: # If still no identifier, cannot proceed
            return None

        try:
            # Try to find user by mobile (USERNAME_FIELD) or email
            user = UserModel.objects.get(Q(mobile=identifier) | Q(email__iexact=identifier))
        except UserModel.DoesNotExist:
            UserModel().set_password(password) # Mitigate timing attacks by running hasher
            return None 
        except UserModel.MultipleObjectsReturned: 
            # This should not happen if mobile and email fields have unique=True constraint
            # on the CustomUser model and it's enforced.
            return None 

        if user.check_password(password) and self.user_can_authenticate(user):
            return user
        
        return None # Password check failed or user cannot authenticate

    def get_user(self, user_id):
        # This method is required for authentication backends.
        # It's used by Django to retrieve a user object given a user ID
        # (e.g., from the session).
        try:
            return UserModel.objects.get(pk=user_id)
        except UserModel.DoesNotExist:
            return None