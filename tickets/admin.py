# tickets/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth import get_user_model # Use this to get the active user model

# Import your other app models
from .models import Ticket, Message

CustomUser = get_user_model() # Get the CustomUser model

# --- Inline for Messages within Ticket Admin ---
class MessageInline(admin.TabularInline): # Or StackedInline
    model = Message
    extra = 0 # Number of empty forms to display (0 is usually better for existing tickets)
    readonly_fields = ('sender', 'content', 'timestamp') # Make inline messages read-only
    can_delete = False # Optionally prevent deleting messages from ticket admin
    fields = ('sender', 'timestamp', 'content') # Control order and fields shown

    def has_add_permission(self, request, obj=None): # Prevent adding new messages via inline
        return False

# --- Ticket Admin ---
@admin.register(Ticket)
class TicketAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'customer', 'agent', 'status', 'priority', 'created_at', 'updated_at')
    list_filter = ('status', 'priority', 'agent', 'created_at')
    search_fields = ('title', 'description', 'customer__username', 'agent__username', 'customer__mobile')
    raw_id_fields = ('agent',)  # Only agent field should be a raw_id field
    readonly_fields = ('customer', 'created_at', 'updated_at')  # Make customer read-only
    date_hierarchy = 'created_at'

    inlines = [MessageInline]

    def get_readonly_fields(self, request, obj=None):
        # If this is a new ticket (obj is None), allow setting the customer
        if obj is None:
            return ('created_at', 'updated_at')
        # For existing tickets, customer should be read-only for everyone, including superusers
        return ('customer', 'created_at', 'updated_at')

# --- Message Admin ---
@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('id', 'ticket_link', 'sender', 'timestamp', 'content_excerpt')
    list_filter = ('sender', 'timestamp', 'ticket__status') # Filter by ticket status
    search_fields = ('content', 'ticket__title', 'sender__username', 'sender__mobile') # Added mobile
    raw_id_fields = ('ticket', 'sender')
    readonly_fields = ('timestamp',)
    date_hierarchy = 'timestamp'

    def content_excerpt(self, obj):
        return obj.content[:50] + '...' if len(obj.content) > 50 else obj.content
    content_excerpt.short_description = 'Content'

    def ticket_link(self, obj):
        from django.urls import reverse
        from django.utils.html import format_html
        if obj.ticket:
            link = reverse("admin:tickets_ticket_change", args=[obj.ticket.id]) # app_label_modelname_change
            return format_html('<a href="{}">{}</a>', link, obj.ticket)
        return None
    ticket_link.short_description = 'Ticket'

# --- Custom User Admin ---
# This registers CustomUser with the CustomUserAdmin options
@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    list_display = ('username', 'email', 'mobile', 'first_name', 'last_name', 'is_staff', 'is_active', 'date_joined')
    search_fields = ('username', 'email', 'mobile', 'first_name', 'last_name')
    ordering = ('username',) # Default ordering
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'groups') # Add groups to filter

    # Fieldsets for the change user page
    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'email', 'mobile')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 
                                   'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )

    # add_fieldsets for the "add user" page in admin
    # BaseUserAdmin.add_fieldsets already includes username and passwords.
    # We are adding our custom fields to a new section.
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Custom Fields', { # Added a title for the section
            'classes': ('wide',),
            # mobile must be here as it's required for CustomUser.
            # email is also in REQUIRED_FIELDS for CustomUser.
            'fields': ('mobile', 'email', 'first_name', 'last_name', 'is_staff', 'is_superuser', 'groups'),
        }),
    )
    # Note: 'groups' and 'user_permissions' are ManyToMany. BaseUserAdmin handles them.
    # If your REQUIRED_FIELDS in CustomUser model are different, adjust 'fields' in add_fieldsets accordingly.