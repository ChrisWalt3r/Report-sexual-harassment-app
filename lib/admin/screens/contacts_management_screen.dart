import 'package:flutter/material.dart';
import '../../models/official_contact.dart';
import '../../services/official_contacts_service.dart';
import '../../constants/app_colors.dart';

/// Admin screen for managing official university contacts
/// These contacts are used by the AI to provide accurate contact information
class ContactsManagementScreen extends StatefulWidget {
  const ContactsManagementScreen({super.key});

  @override
  State<ContactsManagementScreen> createState() => _ContactsManagementScreenState();
}

class _ContactsManagementScreenState extends State<ContactsManagementScreen> {
  final OfficialContactsService _contactsService = OfficialContactsService();
  List<OfficialContact> _contacts = [];
  bool _isLoading = true;
  ContactCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _contactsService.getAllContactsForAdmin();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  List<OfficialContact> get _filteredContacts {
    if (_selectedCategory == null) return _contacts;
    return _contacts.where((c) => c.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Manage Official Contacts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Upload Default Contacts',
            onPressed: _uploadDefaultContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These contacts are used by the AI assistant to provide accurate contact information to users.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          
          // Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(null, 'All'),
                ...ContactCategory.values.map(
                  (cat) => _buildFilterChip(cat, cat.displayName),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGreen),
                  )
                : _filteredContacts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            return _buildContactCard(_filteredContacts[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
        backgroundColor: AppColors.secondaryOrange,
      ),
    );
  }

  Widget _buildFilterChip(ContactCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedCategory = category);
        },
        selectedColor: AppColors.primaryGreen,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_phone_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No contacts found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add official contacts',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _uploadDefaultContacts,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload Default Contacts'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(OfficialContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: contact.isActive 
                  ? _getCategoryColor(contact.category) 
                  : Colors.grey,
              child: Icon(
                _getCategoryIcon(contact.category),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    contact.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: contact.isActive ? null : Colors.grey,
                    ),
                  ),
                ),
                if (!contact.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
            subtitle: Text(contact.title),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showContactDialog(contact);
                    break;
                  case 'toggle':
                    _toggleContactStatus(contact);
                    break;
                  case 'delete':
                    _deleteContact(contact);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(contact.isActive ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (contact.email != null && contact.email!.isNotEmpty)
                  _buildDetailRow(Icons.email, contact.email!),
                if (contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty)
                  _buildDetailRow(Icons.phone, contact.phoneNumber!),
                if (contact.officeLocation != null && contact.officeLocation!.isNotEmpty)
                  _buildDetailRow(Icons.location_on, contact.officeLocation!),
                if (contact.officeHours != null && contact.officeHours!.isNotEmpty)
                  _buildDetailRow(Icons.access_time, contact.officeHours!),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(contact.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contact.category.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getCategoryColor(contact.category),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Priority: ${contact.priority}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(ContactCategory category) {
    switch (category) {
      case ContactCategory.deanOfStudents:
        return AppColors.primaryGreen;
      case ContactCategory.ashc:
        return Colors.purple;
      case ContactCategory.ushc:
        return Colors.indigo;
      case ContactCategory.counseling:
        return Colors.teal;
      case ContactCategory.medical:
        return AppColors.primaryGreen;
      case ContactCategory.security:
        return Colors.red;
      case ContactCategory.humanResources:
        return Colors.orange;
      case ContactCategory.legalServices:
        return Colors.brown;
      case ContactCategory.administration:
        return AppColors.secondaryOrange;
      case ContactCategory.crisisHotline:
        return Colors.deepOrange;
      case ContactCategory.police:
        return Colors.blue;
      case ContactCategory.womenShelter:
        return Colors.pink;
      case ContactCategory.genderDesk:
        return Colors.deepPurple;
      case ContactCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ContactCategory category) {
    switch (category) {
      case ContactCategory.deanOfStudents:
        return Icons.school;
      case ContactCategory.ashc:
        return Icons.gavel;
      case ContactCategory.ushc:
        return Icons.people;
      case ContactCategory.counseling:
        return Icons.psychology;
      case ContactCategory.medical:
        return Icons.local_hospital;
      case ContactCategory.security:
        return Icons.security;
      case ContactCategory.humanResources:
        return Icons.badge;
      case ContactCategory.legalServices:
        return Icons.balance;
      case ContactCategory.administration:
        return Icons.admin_panel_settings;
      case ContactCategory.crisisHotline:
        return Icons.phone_in_talk;
      case ContactCategory.police:
        return Icons.local_police;
      case ContactCategory.womenShelter:
        return Icons.home;
      case ContactCategory.genderDesk:
        return Icons.wc;
      case ContactCategory.other:
        return Icons.contact_phone;
    }
  }

  Future<void> _showContactDialog(OfficialContact? contact) async {
    final isEditing = contact != null;
    
    final nameController = TextEditingController(text: contact?.name ?? '');
    final titleController = TextEditingController(text: contact?.title ?? '');
    final departmentController = TextEditingController(text: contact?.department ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');
    final phoneController = TextEditingController(text: contact?.phoneNumber ?? '');
    final locationController = TextEditingController(text: contact?.officeLocation ?? '');
    final hoursController = TextEditingController(text: contact?.officeHours ?? '');
    final descriptionController = TextEditingController(text: contact?.description ?? '');
    final priorityController = TextEditingController(text: (contact?.priority ?? 10).toString());
    
    ContactCategory selectedCategory = contact?.category ?? ContactCategory.other;

    final result = await showDialog<OfficialContact>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Contact' : 'Add New Contact'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Dropdown
                    DropdownButtonFormField<ContactCategory>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: ContactCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategory = value!);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name / Office *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Dean of Students Office',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Title
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title / Position *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Dean of Students',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Department
                    TextField(
                      controller: departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Student Affairs',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Phone
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: '+256...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Office Location
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Office Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        hintText: 'e.g., Administration Block, Room 201',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Office Hours
                    TextField(
                      controller: hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Office Hours',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                        hintText: 'e.g., Mon-Fri 8:00 AM - 5:00 PM',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Description
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (for AI context)',
                        border: OutlineInputBorder(),
                        hintText: 'What does this contact handle?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Priority
                    TextField(
                      controller: priorityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Priority (1-99)',
                        border: OutlineInputBorder(),
                        helperText: 'Lower number = higher priority',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate required fields
                    if (nameController.text.trim().isEmpty ||
                        titleController.text.trim().isEmpty ||
                        departmentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }
                    
                    final newContact = OfficialContact(
                      id: contact?.id ?? '',
                      name: nameController.text.trim(),
                      title: titleController.text.trim(),
                      department: departmentController.text.trim(),
                      category: selectedCategory,
                      email: emailController.text.trim().isNotEmpty 
                          ? emailController.text.trim() 
                          : null,
                      phoneNumber: phoneController.text.trim().isNotEmpty 
                          ? phoneController.text.trim() 
                          : null,
                      officeLocation: locationController.text.trim().isNotEmpty 
                          ? locationController.text.trim() 
                          : null,
                      officeHours: hoursController.text.trim().isNotEmpty 
                          ? hoursController.text.trim() 
                          : null,
                      description: descriptionController.text.trim().isNotEmpty 
                          ? descriptionController.text.trim() 
                          : null,
                      priority: int.tryParse(priorityController.text) ?? 10,
                      isActive: contact?.isActive ?? true,
                    );
                    
                    Navigator.pop(context, newContact);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (isEditing) {
        await _updateContact(result);
      } else {
        await _addContact(result);
      }
    }
  }

  Future<void> _addContact(OfficialContact contact) async {
    final id = await _contactsService.addContact(contact);
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact added successfully')),
      );
      _loadContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding contact')),
      );
    }
  }

  Future<void> _updateContact(OfficialContact contact) async {
    final success = await _contactsService.updateContact(contact);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact updated successfully')),
      );
      _loadContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating contact')),
      );
    }
  }

  Future<void> _toggleContactStatus(OfficialContact contact) async {
    final success = await _contactsService.toggleContactStatus(
      contact.id,
      !contact.isActive,
    );
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contact.isActive ? 'Contact deactivated' : 'Contact activated',
          ),
        ),
      );
      _loadContacts();
    }
  }

  Future<void> _deleteContact(OfficialContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: Text('Are you sure you want to delete "${contact.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _contactsService.deleteContact(contact.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted')),
        );
        _loadContacts();
      }
    }
  }

  Future<void> _uploadDefaultContacts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Default Contacts?'),
        content: const Text(
          'This will add default MUST official contacts to the database. '
          'Existing contacts with the same info may be duplicated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _contactsService.uploadDefaultContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default contacts uploaded')),
      );
      _loadContacts();
    }
  }
}
