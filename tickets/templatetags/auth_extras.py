# tickets/templatetags/auth_extras.py
from django import template
from django.contrib.auth.models import Group

register = template.Library() # <<< IS THIS LINE EXACTLY LIKE THIS?

@register.filter(name='is_in_group') # <<< AND THIS DECORATOR?
def is_in_group(user, group_name):
    if user.is_authenticated:
        try:
            # Ensure your group names in the template ("Customers", "Agents", "Admins")
            # exactly match the names of the Group objects in your database.
            group = Group.objects.get(name=group_name)
            return group in user.groups.all()
        except Group.DoesNotExist:
            return False # Group doesn't exist, so user can't be in it
    return False # User not authenticated, so can't be in any group