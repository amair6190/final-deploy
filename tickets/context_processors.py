# tickets/context_processors.py

def user_groups(request):
    """
    Adds user's group names and role information to the template context.
    """
    context = {
        'user_groups': [],
        'is_admin': False,
        'is_agent': False,
        'is_customer': False
    }
    
    if request.user.is_authenticated:
        groups = list(request.user.groups.values_list('name', flat=True))
        context['user_groups'] = groups
        context['is_admin'] = request.user.is_superuser or 'Admins' in groups
        context['is_agent'] = 'Agents' in groups
        context['is_customer'] = 'Customers' in groups
    
    return context
