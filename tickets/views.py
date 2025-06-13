# tickets/views.py

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import Group
from django.contrib import messages as django_messages
from django.contrib.auth import login
from django.db.models import Q 
from django.contrib.auth.views import LoginView as DjangoLoginView 
from django.conf import settings
from django.urls import reverse_lazy
from django.http import JsonResponse
from django.utils import timezone
from datetime import timedelta
import traceback

from .models import Ticket, Message, InternalComment, TicketAttachment
from .forms import (
    CustomLoginForm, 
    TicketCreationForm, 
    MessageCreationForm, 
    TicketUpdateForm,
    CustomerRegistrationForm,
    InternalCommentForm
)

def get_date_range_filter():
    """Helper function to return date filters based on the date range"""
    today = timezone.now().date()
    return {
        'today': Q(created_at__date=today),
        'week': Q(created_at__date__gte=today - timedelta(days=7)),
        'month': Q(created_at__date__gte=today - timedelta(days=30)),
    }

def apply_ticket_filters(queryset, request):
    """Apply common filters to ticket queryset based on request parameters"""
    # Search filter
    search_query = request.GET.get('search', '').strip()
    if search_query:
        queryset = queryset.filter(
            Q(title__icontains=search_query) |
            Q(description__icontains=search_query) |
            Q(customer__username__icontains=search_query) |
            Q(id__icontains=search_query)
        )

    # Status filter
    status = request.GET.get('status', '')
    if status:
        queryset = queryset.filter(status=status)

    # Priority filter
    priority = request.GET.get('priority', '')
    if priority:
        queryset = queryset.filter(priority=priority)

    # Date range filter
    date_range = request.GET.get('date_range', '')
    if date_range:
        date_filters = get_date_range_filter()
        if date_range in date_filters:
            queryset = queryset.filter(date_filters[date_range])

    return queryset

def register_customer(request):
    if request.method == 'POST':
        form = CustomerRegistrationForm(request.POST)
        if form.is_valid():
            # print("Form is valid. Attempting to save user...") # Debug print
            try:
                user = form.save() # This calls CustomUser.objects.create_user(...)
                print(f"User {user.username} saved with ID {user.id}. Attempting to add to group...") # Debug print
                
                try:
                    customer_group = Group.objects.get(name='Customers')
                    user.groups.add(customer_group)
                    # print(f"User {user.username} added to 'Customers' group.") # Debug print
                except Group.DoesNotExist:
                    error_msg = "Critical setup error: 'Customers' group not found. Account created but role not assigned."
                    django_messages.error(request, error_msg)
                    print(f"ERROR: {error_msg} for user {user.username}") # Log for admin
                
                # print(f"Attempting to login user {user.username}...") # Debug print
                # Specify the backend when logging in the user after registration
                login(request, user, backend='tickets.backends.MobileOrEmailBackend')
                django_messages.success(request, f'Welcome, {user.get_full_name() or user.username}! Your account has been created and you are now logged in.')
                return redirect('tickets:customer_dashboard')
            
            except Exception as e:
                # This will catch errors during form.save() or subsequent operations before redirect
                error_message = f"An unexpected error occurred during registration: {e}"
                django_messages.error(request, error_message)
                print(f"--- REGISTRATION EXCEPTION ---")
                print(error_message)
                traceback.print_exc() # Print full traceback to console
                print(f"----------------------------")
                # Re-render the form. The form instance `form` will still contain
                # the submitted data and any validation errors if is_valid() was True
                # but save() failed. If is_valid() was false, this part isn't reached.
                # If save() itself failed due to model validation not caught by form validation,
                # the form might not show those errors directly without custom handling.
                
        else: # form.is_valid() is False
            django_messages.error(request, "Registration failed. Please correct the errors highlighted below.")
            print("--- REGISTRATION FORM ERRORS ---")
            for field, errors in form.errors.items():
                print(f"Field: {field}, Errors: {', '.join(errors)}")
            if form.non_field_errors():
                print(f"Non-field errors: {', '.join(form.non_field_errors())}")
            print(f"------------------------------")
    else: # GET request
        form = CustomerRegistrationForm()
    
    return render(request, 'tickets/register_customer.html', {'form': form})

# --- Helper function for checking group ---
def is_in_group(user, group_name):
    # Ensure user is authenticated before checking groups
    if user.is_authenticated:
        return user.groups.filter(name=group_name).exists()
    return False

# --- User Registration ---


# --- Customer Views ---
@login_required
def customer_dashboard(request):
    if not is_in_group(request.user, 'Customers'):
        django_messages.error(request, "Access Denied. This dashboard is for customers only.")
        if is_in_group(request.user, 'Agents'):
            return redirect('tickets:agent_dashboard')
        return redirect('tickets:login')

    # Get all tickets for the current customer
    tickets = Ticket.objects.filter(customer=request.user).order_by('-created_at')
    
    # Apply filters
    tickets = apply_ticket_filters(tickets, request)

    context = {
        'tickets': tickets,
    }
    return render(request, 'tickets/customer_dashboard.html', context)

@login_required
def create_ticket(request):
    if not is_in_group(request.user, 'Customers'):
        django_messages.error(request, "Access Denied. Only customers can create tickets.")
        # Redirect based on actual role if possible, or to home/login
        if is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins'):
            return redirect('tickets:agent_dashboard') # Agents might have a different "create" flow or none
        return redirect('tickets:login')

    if request.method == 'POST':
        form = TicketCreationForm(request.POST, request.FILES)
        if form.is_valid():
            ticket = form.save(commit=False)
            ticket.customer = request.user
            ticket.status = 'OPEN' 
            ticket.save()
            
            # Handle file attachments
            attachments = form.cleaned_data.get('attachments')
            if attachments:
                if isinstance(attachments, list):
                    for attachment in attachments:
                        TicketAttachment.objects.create(
                            ticket=ticket,
                            file=attachment,
                            uploaded_by=request.user
                        )
                else:
                    TicketAttachment.objects.create(
                        ticket=ticket,
                        file=attachments,
                        uploaded_by=request.user
                    )
            
            django_messages.success(request, 'Ticket created successfully!')
            return redirect('tickets:ticket_detail', ticket_id=ticket.id)
    else:
        form = TicketCreationForm()
    return render(request, 'tickets/create_ticket.html', {'form': form})

@login_required
def ticket_detail(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)
    is_customer = is_in_group(request.user, 'Customers')
    is_agent = is_in_group(request.user, 'Agents')
    is_admin = is_in_group(request.user, 'Admins')

    # Security Checks
    if is_customer and ticket.customer != request.user:
        django_messages.error(request, "You are not authorized to view this ticket.")
        return redirect('tickets:customer_dashboard')
    
    # Agents can only view tickets assigned to them (unless they're admins)
    if is_agent and not is_admin and not request.user.is_superuser:
        if ticket.agent != request.user:
            django_messages.error(request, "You can only view tickets assigned to you.")
            return redirect('tickets:agent_dashboard')
    
    # If not customer, agent, or admin, deny access
    if not (is_customer or is_agent or is_admin or request.user.is_superuser):
        django_messages.error(request, "You do not have permission to view this page.")
        return redirect('home')

    if request.method == 'POST':
        if 'internal_comment' in request.POST and (is_agent or is_admin or request.user.is_superuser):
            internal_comment_form = InternalCommentForm(request.POST)
            if internal_comment_form.is_valid():
                comment = internal_comment_form.save(commit=False)
                comment.ticket = ticket
                comment.author = request.user
                comment.save()
                ticket.save()  # Update the ticket's updated_at timestamp
                
                if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                    return JsonResponse({
                        'success': True,
                        'message': 'Internal comment added successfully!'
                    })
                
                django_messages.success(request, 'Internal comment added successfully!')
                return redirect('tickets:ticket_detail', ticket_id=ticket.id)
        else:
            message_form = MessageCreationForm(request.POST, request.FILES)
            if message_form.is_valid():
                message = message_form.save(commit=False)
                message.ticket = ticket
                message.sender = request.user
                # Ensure via_whatsapp is set (defaults to False for web interface)
                if not hasattr(message, 'via_whatsapp') or message.via_whatsapp is None:
                    message.via_whatsapp = False
                message.save()
                ticket.save()  # Update the ticket's updated_at timestamp
                
                if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                    return JsonResponse({
                        'success': True,
                        'message': 'Message posted successfully!'
                    })
                
                django_messages.success(request, 'Message posted successfully!')
                return redirect('tickets:ticket_detail', ticket_id=ticket.id)
    else:
        message_form = MessageCreationForm()
        internal_comment_form = InternalCommentForm() if (is_agent or is_admin or request.user.is_superuser) else None

    messages_queryset = ticket.messages.all().order_by('created_at')
    internal_comments = ticket.internal_comments.all().order_by('created_at') if (is_agent or is_admin or request.user.is_superuser) else None
    
    ticket_update_form = None
    if (is_agent and ticket.agent == request.user) or is_admin or request.user.is_superuser:
        ticket_update_form = TicketUpdateForm(instance=ticket)

    # Get ticket attachments
    ticket_attachments = ticket.attachments.all().order_by('-uploaded_at')

    context = {
        'ticket': ticket,
        'messages_list': messages_queryset,
        'message_form': message_form,
        'internal_comments': internal_comments,
        'internal_comment_form': internal_comment_form,
        'ticket_update_form': ticket_update_form,
        'ticket_attachments': ticket_attachments,
        'is_customer': is_customer,
        'is_agent': is_agent or is_admin or request.user.is_superuser,
    }
    return render(request, 'tickets/ticket_detail.html', context)


# --- Agent Views ---
@login_required
def agent_dashboard(request):
    if not (is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins') or request.user.is_superuser):
        django_messages.error(request, "Access Denied. This dashboard is for agents and administrators.")
        if is_in_group(request.user, 'Customers'):
            return redirect('tickets:customer_dashboard')
        return redirect('tickets:login')

    # Initialize queries with status filtering for unresolved tickets
    unassigned_tickets = Ticket.objects.filter(agent__isnull=True).exclude(status='RESOLVED')
    assigned_tickets = Ticket.objects.filter(agent__isnull=False).exclude(status='RESOLVED')
    
    # Filter based on assignment status
    assignment_filter = request.GET.get('assigned', '')
    if assignment_filter == 'unassigned':
        assigned_tickets = Ticket.objects.none()
    elif assignment_filter == 'assigned_to_me':
        assigned_tickets = assigned_tickets.filter(agent=request.user)
    elif assignment_filter == 'all_assigned' and (request.user.is_superuser or is_in_group(request.user, 'Admins')):
        pass  # Keep all assigned tickets for admins
    else:
        # Default: Show unassigned and tickets assigned to current agent
        assigned_tickets = assigned_tickets.filter(agent=request.user)

    # Apply common filters to both querysets
    unassigned_tickets = apply_ticket_filters(unassigned_tickets, request)
    assigned_tickets = apply_ticket_filters(assigned_tickets, request)

    # Get resolved tickets (limited to 10)
    resolved_tickets_query = Q(status='RESOLVED')
    if not (request.user.is_superuser or is_in_group(request.user, 'Admins')):
        resolved_tickets_query &= Q(agent=request.user)
    resolved_tickets = Ticket.objects.filter(resolved_tickets_query).order_by('-updated_at')[:10]

    context = {
        'unassigned_tickets': unassigned_tickets.exclude(status='RESOLVED'),
        'assigned_tickets': assigned_tickets.exclude(status='RESOLVED'),
        'resolved_tickets': resolved_tickets,
        'is_admin': request.user.is_superuser or is_in_group(request.user, 'Admins'),
        'is_agent': is_in_group(request.user, 'Agents'),
    }
    return render(request, 'tickets/agent_dashboard.html', context)

@login_required
def assign_ticket_to_self(request, ticket_id):
    if not (is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins') or request.user.is_superuser):
        django_messages.error(request, "Access Denied. Only agents can assign tickets.")
        return redirect('tickets:agent_dashboard')

    ticket = get_object_or_404(Ticket, id=ticket_id)
    
    # Check if the ticket is already assigned
    if ticket.agent is not None:
        if ticket.agent == request.user:
            django_messages.warning(request, f'Ticket #{ticket.id} is already assigned to you.')
        else:
            django_messages.warning(request, f'Ticket #{ticket.id} is already assigned to {ticket.agent.username}.')
        return redirect('tickets:ticket_detail', ticket_id=ticket.id)
    
    # Assign the ticket
    ticket.agent = request.user
    ticket.status = 'IN_PROGRESS'
    ticket.save()
    django_messages.success(request, f'Ticket #{ticket.id} has been assigned to you.')
    return redirect('tickets:ticket_detail', ticket_id=ticket.id)


@login_required
def update_ticket_by_agent(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)
    is_admin = is_in_group(request.user, 'Admins')
    
    # Check if user is assigned agent, an Admin, or superuser
    if not (request.user == ticket.agent or is_admin or request.user.is_superuser):
        django_messages.error(request, "You can only update tickets assigned to you.")
        return redirect('tickets:ticket_detail', ticket_id=ticket.id)

    if request.method == 'POST':
        form = TicketUpdateForm(request.POST, instance=ticket)
        if form.is_valid():
            form.save()
            django_messages.success(request, f'Ticket #{ticket.id} status updated.')
            return redirect('tickets:ticket_detail', ticket_id=ticket.id)
        else:
            django_messages.error(request, "Error updating ticket. Please check the form.")
            return redirect('tickets:ticket_detail', ticket_id=ticket.id)

    return redirect('tickets:ticket_detail', ticket_id=ticket.id)


# --- Basic Home Page ---
def home(request):
    if request.user.is_authenticated:
        if is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins') or request.user.is_superuser:
            return redirect('tickets:agent_dashboard')
        elif is_in_group(request.user, 'Customers'): # Check customer after agent/admin
            return redirect('tickets:customer_dashboard')
        else:
            # Authenticated user with no specific group - decide where they go
            # Maybe a generic profile page or logout with a message.
            # For now, an unprivileged authenticated user could see the public home.
            pass 
    return render(request, 'home.html') 


# --- Custom Login View ---
class CustomLoginView(DjangoLoginView):
    form_class = CustomLoginForm
    template_name = 'tickets/login.html'

    def form_valid(self, form):
        remember_me = form.cleaned_data.get('remember_me')
        if not remember_me:
            self.request.session.set_expiry(0)
        else:
            self.request.session.set_expiry(settings.SESSION_COOKIE_AGE_REMEMBER_ME)
        self.request.session.modified = True
        return super().form_valid(form)

    def get_success_url(self):
        user = self.request.user
        # Superusers/staff go to agent dashboard (or Django admin)
        if user.is_superuser or (user.is_staff and not is_in_group(user, 'Customers')): # Staff but not primarily a customer
            return reverse_lazy('tickets:agent_dashboard') # Or 'admin:index'

        if is_in_group(user, 'Agents') or is_in_group(user, 'Admins'):
            return reverse_lazy('tickets:agent_dashboard')
        elif is_in_group(user, 'Customers'):
            return reverse_lazy('tickets:customer_dashboard')
        
        # Fallback if no specific group, or if user is staff but also a customer,
        # default to LOGIN_REDIRECT_URL or home.
        # This also handles the case where a user is just 'staff' without being in Agent/Admin group.
        if hasattr(settings, 'LOGIN_REDIRECT_URL'):
             # Use try-except for reverse_lazy in case LOGIN_REDIRECT_URL is not a named URL pattern
            try:
                return reverse_lazy(settings.LOGIN_REDIRECT_URL)
            except Exception:
                return settings.LOGIN_REDIRECT_URL # Return as string if not a name
        return reverse_lazy('home')

