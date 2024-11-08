import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChecklistListPage extends StatefulWidget {
  final int userId; // Accept userId

  const ChecklistListPage({super.key, required this.userId}); // Constructor

  @override
  _ChecklistListPageState createState() => _ChecklistListPageState();
}

class _ChecklistListPageState extends State<ChecklistListPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _checklists = [];
  List<Map<String, dynamic>> _categories = []; // Store categories here
  final TextEditingController _checklistNameController =
      TextEditingController(); // Controller for new checklist
  final TextEditingController _categoryNameController =
      TextEditingController(); // Controller for new category
  final TextEditingController _editCategoryNameController =
      TextEditingController(); // Controller for editing category
  bool isLoading = true;
  int? _selectedCategoryId; // Store selected categoryID
  bool _isCategorySelected = false; // Track if a category is selected
  String _selectedCategoryName =
      'List of Checklists'; // Store the selected category name

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // Fetch categories first
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch the categories for the current user
      final response = await supabase
          .from('checklistCategory')
          .select()
          .eq('userID', widget.userId);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      // Handle error here
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchChecklists() async {
    if (_selectedCategoryId == null) return; // Ensure categoryID is selected
    try {
      // Fetch the checklist data for the selected category
      final response = await supabase
          .from('checklistTable')
          .select()
          .eq('userID', widget.userId)
          .eq('categoryID', _selectedCategoryId as Object);

      setState(() {
        _checklists = List<Map<String, dynamic>>.from(response ?? []);
        isLoading = false;
      });
    } catch (e) {
      // Handle error here
      print('Error fetching checklists: $e');
    }
  }

  Future<void> _addChecklist() async {
    if (_checklistNameController.text.isNotEmpty &&
        _selectedCategoryId != null) {
      try {
        await supabase.from('checklistTable').insert({
          'list': _checklistNameController.text,
          'userID': widget.userId,
          'checked': false,
          'categoryID': _selectedCategoryId, // Add selected categoryID
        });

        // Refresh the list
        _fetchChecklists();
        _checklistNameController.clear();
      } catch (e) {
        // Handle error here
        print('Error adding checklist: $e');
      }
    }
  }

  Future<void> _deleteChecklist(int checklistId) async {
    try {
      await supabase.from('checklistTable').delete().eq('id', checklistId);
      _fetchChecklists(); // Refresh the list after deletion
    } catch (e) {
      // Handle error here
      print('Error deleting checklist: $e');
    }
  }

  Future<void> _toggleChecklistChecked(
      int checklistId, bool currentValue) async {
    try {
      await supabase
          .from('checklistTable')
          .update({'checked': !currentValue}).eq('id', checklistId);
      _fetchChecklists(); // Refresh after toggling the checked status
    } catch (e) {
      // Handle error here
      print('Error updating checklist: $e');
    }
  }

  // Function to add a new category
  Future<void> _addNewCategory() async {
    if (_categoryNameController.text.isNotEmpty) {
      try {
        await supabase.from('checklistCategory').insert({
          'name': _categoryNameController.text,
          'userID': widget.userId,
        });

        // Refresh the categories list
        _fetchCategories();
        _categoryNameController.clear();
        Navigator.of(context).pop(); // Close the dialog
      } catch (e) {
        print('Error adding category: $e');
      }
    }
  }

  // Function to update a category
  Future<void> _updateCategory(int categoryId) async {
    if (_editCategoryNameController.text.isNotEmpty) {
      try {
        await supabase.from('checklistCategory').update(
            {'name': _editCategoryNameController.text}).eq('id', categoryId);

        // Refresh categories
        _fetchCategories();
        Navigator.of(context).pop(); // Close the dialog
      } catch (e) {
        print('Error updating category: $e');
      }
    }
  }

  // Function to delete a category and its associated checklists
  Future<void> _deleteCategory(int categoryId) async {
    try {
      await supabase
          .from('checklistTable')
          .delete()
          .eq('categoryID', categoryId); // Delete associated checklists
      await supabase
          .from('checklistCategory')
          .delete()
          .eq('id', categoryId); // Delete the category itself

      // Refresh categories after deletion
      _fetchCategories();
    } catch (e) {
      print('Error deleting category: $e');
    }
  }

  // Show a dialog to update the category
  void _showEditCategoryDialog(int categoryId, String currentName) {
    _editCategoryNameController.text = currentName;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Category"),
          content: TextField(
            controller: _editCategoryNameController,
            decoration:
                const InputDecoration(hintText: "Enter new category name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close without saving
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _updateCategory(categoryId); // Call update function
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation dialog before deleting category
  void _showDeleteCategoryConfirmation(int categoryId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Category"),
          content: const Text(
              "Are you sure you want to delete this category and all its associated checklists?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close without action
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteCategory(categoryId); // Delete category
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // Function to show a dialog for entering a new category name
  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add New Category"),
          content: TextField(
            controller: _categoryNameController,
            decoration: const InputDecoration(hintText: "Enter category name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without action
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _addNewCategory,
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Function to show a dialog for adding a new checklist in the selected category
  void _showAddChecklistDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add New Checklist"),
          content: TextField(
            controller: _checklistNameController,
            decoration: const InputDecoration(hintText: "Enter checklist item"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without action
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _addChecklist(); // Call the function to add the checklist
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    // Handle the back button behavior
    if (_isCategorySelected) {
      // If a category is selected, go back to the category list
      setState(() {
        _isCategorySelected = false;
        _selectedCategoryName = 'List of Checklists'; // Reset title to default
      });
      return false; // Prevent default back navigation
    } else {
      return true; // Allow default back navigation
    }
  }

  // Function to update a checklist item
  Future<void> _updateChecklist(int checklistId) async {
    if (_checklistNameController.text.isNotEmpty) {
      try {
        await supabase.from('checklistTable').update({
          'list': _checklistNameController.text,
        }).eq('id', checklistId);

        // Refresh the checklist after update
        _fetchChecklists();
        _checklistNameController.clear();
        Navigator.of(context).pop(); // Close the dialog
      } catch (e) {
        print('Error updating checklist: $e');
      }
    }
  }

// Show a dialog to update the checklist item
  void _showEditChecklistDialog(int checklistId, String currentName) {
    _checklistNameController.text = currentName;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Checklist Item"),
          content: TextField(
            controller: _checklistNameController,
            decoration:
                const InputDecoration(hintText: "Enter new checklist item"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close without saving
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _updateChecklist(checklistId); // Call update function
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

// Show confirmation dialog before deleting checklist
  void _showDeleteChecklistConfirmation(int checklistId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Checklist"),
          content: const Text(
              "Are you sure you want to delete this checklist item?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close without action
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteChecklist(checklistId); // Delete checklist item
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // Modify the ListTile widget in the ListView.builder for checklists
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isCategorySelected ? _selectedCategoryName : 'List of Checklists',
            style: const TextStyle(
              color: Color(0xFFEBE0D0),
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFFA91B60),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _isCategorySelected
                        ? Expanded(
                            child: ListView.builder(
                              itemCount: _checklists.length,
                              itemBuilder: (context, index) {
                                final checklist = _checklists[index];
                                return Card(
                                  elevation: 4.0,
                                  color: checklist['checked']
                                      ? Colors.grey.shade300
                                      : const Color(0xFFEBE0D0),
                                  child: ListTile(
                                    title: Text(
                                      checklist['list'],
                                      style: TextStyle(
                                        color: checklist['checked']
                                            ? Colors.grey
                                            : const Color(0xFFA91B60),
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        decoration: checklist['checked']
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Color(0xFFA91B60)),
                                          onPressed: () {
                                            _showEditChecklistDialog(
                                                checklist['id'],
                                                checklist[
                                                    'list']); // Show edit dialog
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            _deleteChecklist(checklist['id']);
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _toggleChecklistChecked(checklist['id'],
                                          checklist['checked']);
                                    },
                                    onLongPress: () =>
                                        _deleteChecklist(checklist['id']),
                                  ),
                                );
                              },
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                return Card(
                                  elevation: 4.0,
                                  color: const Color(0xFFEBE0D0),
                                  child: ListTile(
                                    title: Text(
                                      category['name'],
                                      style: const TextStyle(
                                        color: Color(0xFFA91B60),
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Color(0xFFA91B60)),
                                          onPressed: () {
                                            _showEditCategoryDialog(
                                                category['id'],
                                                category['name']);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            _showDeleteCategoryConfirmation(
                                                category['id']);
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryId = category['id'];
                                        _selectedCategoryName =
                                            category['name'];
                                        _isCategorySelected = true;
                                        _fetchChecklists();
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
        floatingActionButton: _isCategorySelected
            ? FloatingActionButton(
                onPressed: _showAddChecklistDialog,
                child: const Icon(Icons.add),
              )
            : FloatingActionButton(
                onPressed: _showAddCategoryDialog,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
