# tickets/context_processors.py

def user_groups(request):
    """
    Adds user's group names to the template context.
    """
    if request.user.is_authenticated:
        groups = request.user.groups.values_list('name', flat=True)
        return {'user_groups': list(groups)}
    return {'user_groups': []}
