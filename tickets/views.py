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
import traceback # Import for detailed tracebacks

from .models import Ticket, Message # Assuming CustomUser is imported via settings.AUTH_USER_MODEL
from .forms import (
    CustomLoginForm, 
    TicketCreationForm, 
    MessageCreationForm, 
    TicketUpdateForm,
    CustomerRegistrationForm
)

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
                login(request, user)
                django_messages.success(request, f'Welcome, {user.username}! Your account has been created and you are now logged in.')
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
        django_messages.error(request, "Access Denied. This dashboard is for customers.")
        # Redirect based on actual role if possible, or to home/login
        if is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins'):
            return redirect('tickets:agent_dashboard')
        return redirect('tickets:login') 

    tickets = Ticket.objects.filter(customer=request.user).order_by('-created_at')
    return render(request, 'tickets/customer_dashboard.html', {'tickets': tickets})

@login_required
def create_ticket(request):
    if not is_in_group(request.user, 'Customers'):
        django_messages.error(request, "Access Denied. Only customers can create tickets.")
        # Redirect based on actual role if possible, or to home/login
        if is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins'):
            return redirect('tickets:agent_dashboard') # Agents might have a different "create" flow or none
        return redirect('tickets:login')

    if request.method == 'POST':
        form = TicketCreationForm(request.POST)
        if form.is_valid():
            ticket = form.save(commit=False)
            ticket.customer = request.user
            ticket.status = 'OPEN' 
            ticket.save()
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
    is_admin = is_in_group(request.user, 'Admins') # Good to check for admin too

    # Security Checks
    if is_customer and ticket.customer != request.user:
        django_messages.error(request, "You are not authorized to view this ticket.")
        return redirect('tickets:customer_dashboard')
    
    # Agents/Admins can view any ticket (adjust if agents should only see assigned/departmental)
    if not (is_customer or is_agent or is_admin or request.user.is_superuser):
        django_messages.error(request, "You do not have permission to view this page.")
        return redirect('home') # Or appropriate page

    if request.method == 'POST':
        message_form = MessageCreationForm(request.POST)
        if message_form.is_valid():
            message = message_form.save(commit=False)
            message.ticket = ticket
            message.sender = request.user # 'sender' field in Message model
            message.save()
            ticket.save() # To update ticket's updated_at
            django_messages.success(request, 'Message posted successfully!')
            return redirect('tickets:ticket_detail', ticket_id=ticket.id)
        # else: handle invalid message_form if necessary
    else:
        message_form = MessageCreationForm()

    messages_queryset = ticket.messages.all().order_by('timestamp') # Changed from 'messages' to 'messages_queryset'
    ticket_update_form = None
    if is_agent or is_admin or request.user.is_superuser: 
        ticket_update_form = TicketUpdateForm(instance=ticket)

    context = {
        'ticket': ticket,
        'messages_list': messages_queryset, # Use a different name to avoid conflict if 'messages' is used by context processor
        'message_form': message_form,
        'ticket_update_form': ticket_update_form,
        'is_customer': is_customer,
        'is_agent': is_agent or is_admin or request.user.is_superuser, # Allow admins to act as agents
    }
    return render(request, 'tickets/ticket_detail.html', context)


# --- Agent Views ---
@login_required
def agent_dashboard(request):
    # More robust check for agent/admin access
    if not (is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins') or request.user.is_superuser):
        django_messages.error(request, "Access Denied. This dashboard is for agents and administrators.")
        if is_in_group(request.user, 'Customers'):
            return redirect('tickets:customer_dashboard')
        return redirect('tickets:login')

    unassigned_tickets = Ticket.objects.filter(agent__isnull=True, status__in=['OPEN', 'IN_PROGRESS']).order_by('-created_at')
    # For agents, show only tickets assigned to them. Admins/superusers might see all assigned.
    if request.user.is_superuser or is_in_group(request.user, 'Admins'):
        assigned_tickets = Ticket.objects.filter(agent__isnull=False, status__in=['OPEN', 'IN_PROGRESS']).order_by('-created_at')
    else: # Regular agent
        assigned_tickets = Ticket.objects.filter(agent=request.user, status__in=['OPEN', 'IN_PROGRESS']).order_by('-created_at')
    
    resolved_tickets_query = Q(status='RESOLVED')
    if not (request.user.is_superuser or is_in_group(request.user, 'Admins')): # Agent only sees their resolved
        resolved_tickets_query &= Q(agent=request.user)
    resolved_tickets = Ticket.objects.filter(resolved_tickets_query).order_by('-updated_at')[:10]

    context = {
        'unassigned_tickets': unassigned_tickets,
        'assigned_tickets': assigned_tickets,
        'resolved_tickets': resolved_tickets,
    }
    return render(request, 'tickets/agent_dashboard.html', context)

@login_required
def assign_ticket_to_self(request, ticket_id):
    if not (is_in_group(request.user, 'Agents') or is_in_group(request.user, 'Admins') or request.user.is_superuser):
        django_messages.error(request, "Access Denied.")
        return redirect('home') # Or agent dashboard if they somehow got here without being an agent

    ticket = get_object_or_404(Ticket, id=ticket_id)
    if ticket.agent is None:
        ticket.agent = request.user
        ticket.status = 'IN_PROGRESS' 
        ticket.save()
        django_messages.success(request, f'Ticket #{ticket.id} assigned to you.')
    else:
        django_messages.warning(request, f'Ticket #{ticket.id} is already assigned to {ticket.agent.username}.')
    return redirect('tickets:ticket_detail', ticket_id=ticket.id)


@login_required
def update_ticket_by_agent(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)
    # Check if user is assigned agent, an Admin, or superuser
    if not (request.user == ticket.agent or is_in_group(request.user, 'Admins') or request.user.is_superuser):
        django_messages.error(request, "You do not have permission to update this ticket.")
        return redirect('tickets:ticket_detail', ticket_id=ticket.id)

    if request.method == 'POST':
        form = TicketUpdateForm(request.POST, instance=ticket)
        if form.is_valid():
            form.save()
            django_messages.success(request, f'Ticket #{ticket.id} status updated.')
            # No need to redirect here, the form submission is usually via AJAX or from ticket_detail page itself.
            # If this view is a standalone page for updating, then redirect.
            # For now, assuming it's part of ticket_detail's POST handling.
            return redirect('tickets:ticket_detail', ticket_id=ticket.id) 
        else:
            # If form is invalid, typically you re-render the page with the form and errors.
            # This might mean ticket_detail needs to handle displaying ticket_update_form with errors.
            # For simplicity in this example, we'll just show a generic message and redirect.
            django_messages.error(request, "Error updating ticket. Please check the form.")
            # Storing form errors in messages to display on redirect is tricky.
            # Better to re-render the page where the form was.
            # This redirect might lose form error context.
            return redirect('tickets:ticket_detail', ticket_id=ticket.id)

    # If GET, typically this view isn't directly accessed or it displays a form.
    # Since update is usually a POST from ticket_detail, a GET here might be unusual.
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
    
