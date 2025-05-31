from django import template
from django.contrib.auth.models import Group

register = template.Library() # You need to instantiate a Library object

@register.filter(name='is_in_group')
def is_in_group(user, group_name):
    """
    Checks if a user is a member of a specific group.
    Usage: {{ user|is_in_group:"GroupName" }}
    """
    if user.is_authenticated: # Only check for authenticated users
        try:
            group = Group.objects.get(name=group_name)
            return group in user.groups.all()
        except Group.DoesNotExist:
            return False # Group doesn't exist
    return False # User is not authenticated
