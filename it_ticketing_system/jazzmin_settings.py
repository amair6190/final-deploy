# Add this to your settings.py for django-jazzmin theme

# JAZZMIN SETTINGS
JAZZMIN_SETTINGS = {
    # Title of the window (Will default to current_admin_site.site_header if absent or None)
    "site_title": "SolvIT Admin",

    # Title on the login screen (19 chars max) (defaults to current_admin_site.site_header if absent or None)
    "site_header": "SolvIT",

    # Title on the brand (19 chars max) (defaults to current_admin_site.site_header if absent or None)
    "site_brand": "SolvIT Ticketing",

    # Logo to use for your site, must be present in static files, used for brand on top left
    "site_logo": "images/your_solvit_logo.png",

    # Logo to use for your site, must be present in static files, used for login form logo
    "login_logo": "images/your_solvit_logo.png",

    # Logo to use for login form in dark themes
    "login_logo_dark": "images/your_solvit_logo.png",

    # CSS classes that are applied to the logo above
    "site_logo_classes": "img-circle",

    # Relative path to a favicon for your site, will default to site_logo if absent
    "site_icon": "images/your_solvit_logo.png",

    # Welcome text on the login screen
    "welcome_sign": "Welcome to SolvIT Ticketing System",

    # Copyright on the footer
    "copyright": "SolvIT Solutions",

    # List of model admins to search from the search bar, search bar omitted if excluded
    "search_model": ["auth.User", "tickets.Ticket"],

    # Field names on the user model
    "user_avatar": None,

    ############
    # Top Menu #
    ############

    # Links to put along the top menu
    "topmenu_links": [
        # Url that gets reversed (Permissions can be added)
        {"name": "Home", "url": "admin:index", "permissions": ["auth.view_user"]},

        # external url that opens in a new window (Permissions can be added)
        {"name": "Support", "url": "https://github.com/amair6190/solvit-ticketing-system", "new_window": True},

        # model admin to link to (Permissions checked against model)
        {"model": "auth.User"},

        # App with dropdown menu to all its models pages (Permissions checked against models)
        {"app": "tickets"},
    ],

    #############
    # User Menu #
    #############

    # Additional links to include in the user menu on the top right ("app" url type is not allowed)
    "usermenu_links": [
        {"name": "Support", "url": "https://github.com/amair6190/solvit-ticketing-system", "new_window": True},
        {"model": "auth.user"}
    ],

    #############
    # Side Menu #
    #############

    # Whether to display the side menu
    "show_sidebar": True,

    # Whether to aut expand the menu
    "navigation_expanded": True,

    # Hide these apps when generating side menu e.g (auth)
    "hide_apps": [],

    # Hide these models when generating side menu (e.g auth.user)
    "hide_models": [],

    # List of apps (and models) to base side menu ordering off of (does not need to contain all apps/models)
    "order_with_respect_to": ["auth", "tickets"],

    # Custom links to append to app groups, keyed on app name
    "custom_links": {
        "tickets": [{
            "name": "Create New Ticket", 
            "url": "admin:tickets_ticket_add", 
            "icon": "fas fa-ticket-alt",
            "permissions": ["tickets.add_ticket"]
        }]
    },

    # Custom icons for side menu apps/models See https://fontawesome.com/icons?d=gallery&m=free&v=5.0.0,5.0.1,5.0.10,5.0.11,5.0.12,5.0.13,5.0.2,5.0.3,5.0.4,5.0.5,5.0.6,5.0.7,5.0.8,5.0.9,5.1.0,5.1.1,5.2.0,5.3.0,5.3.1,5.4.0,5.4.1,5.4.2,5.5.0,5.6.0,5.6.1,5.6.3,5.7.0,5.7.1,5.7.2,5.8.0,5.8.1,5.8.2,5.9.0,5.10.0,5.10.1,5.10.2,5.11.0,5.11.1,5.11.2,5.12.0,5.12.1,5.13.0,5.13.1,5.14.0,5.15.0,5.15.1,5.15.2,5.15.3,5.15.4&s=solid
    "icons": {
        "auth": "fas fa-users-cog",
        "auth.user": "fas fa-user",
        "auth.Group": "fas fa-users",
        "tickets.Ticket": "fas fa-ticket-alt",
        "tickets.Message": "fas fa-comments",
        "tickets.CustomUser": "fas fa-user-circle",
    },

    # Icons that are used when one is not manually specified
    "default_icon_parents": "fas fa-chevron-circle-right",
    "default_icon_children": "fas fa-circle",

    #################
    # Related Modal #
    #################
    # Use modals instead of popups
    "related_modal_active": False,

    #############
    # UI Tweaks #
    #############
    # Relative paths to custom CSS/JS scripts (must be present in static files)
    "custom_css": "admin/css/custom_admin.css",
    "custom_js": None,
    # Whether to link font from fonts.googleapis.com (use custom_css to supply font otherwise)
    "use_google_fonts_cdn": True,
    # Whether to show the UI customizer on the sidebar
    "show_ui_builder": True,

    ###############
    # Change view #
    ###############
    # Render out the change view as a single form, or in tabs, current options are
    # - single
    # - horizontal_tabs (default)
    # - vertical_tabs
    # - collapsible
    # - carousel
    "changeform_format": "horizontal_tabs",
    # override change forms on a per modeladmin basis
    "changeform_format_overrides": {"auth.user": "collapsible", "auth.group": "vertical_tabs"},
    # Add a language dropdown into the side menu
    "language_chooser": False,
}

# UI Tweaks to match SolvIT color scheme
JAZZMIN_UI_TWEAKS = {
    "theme": "darkly",
    "navbar_small_text": False,
    "footer_small_text": False,
    "body_small_text": False,
    "brand_small_text": False,
    "brand_colour": "navbar-primary",
    "accent": "accent-primary",
    "navbar": "navbar-dark",
    "no_navbar_border": False,
    "navbar_fixed": False,
    "layout_boxed": False,
    "footer_fixed": False,
    "sidebar_fixed": False,
    "sidebar": "sidebar-dark-primary",
    "sidebar_nav_small_text": False,
    "sidebar_disable_expand": False,
    "sidebar_nav_child_indent": False,
    "sidebar_nav_compact_style": False,
    "sidebar_nav_legacy_style": False,
    "sidebar_nav_flat_style": False,
    "actions_sticky_top": False,
}
