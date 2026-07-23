extends Node

# Inventory Manager - Handles item storage and interactions
class_name InventoryManager

# Item data structure
class ItemData:
    var id: int = 0
    var name: String = ""
    var description: String = ""
    var color: Color = Color(1, 1, 1)
    var stack_size: int = 99
    var current_count: int = 0

    func _init(_id: int = 0, _name: String = "", _desc: String = "", _color: Color = Color(0.5, 0.5, 0.5), _max_stack: int = 99):
        id = _id
        name = _name
        description = _desc
        color = _color
        stack_size = _max_stack
        current_count = 1

# Demo items database
var demo_items: Array = [
    ItemData.new(1, "Healing Potion", "Restores 50 HP", Color(0.9, 0.2, 0.3), 10),
    ItemData.new(2, "Steel Sword", "A sturdy blade", Color(0.7, 0.7, 0.8), 1),
    ItemData.new(3, "Leather Armor", "Protective armor", Color(0.6, 0.4, 0.2), 1),
    ItemData.new(4, "Magic Scroll", "Contains powerful magic", Color(0.4, 0.6, 1.0), 5),
    ItemData.new(5, "Gold Coins", "Currency", Color(1.0, 0.8, 0.0), 100),
    ItemData.new(6, "Lockpick Set", "Opens locks", Color(0.5, 0.5, 0.5), 1),
    ItemData.new(7, "Rope", "20ft of rope", Color(0.8, 0.6, 0.4), 10),
    ItemData.new(8, "Torch", "Light in darkness", Color(1.0, 0.6, 0.1), 5)
]

# Slot references
@onready var slots: Array = [
    $InventoryWindow/GridContainerBackground/Slot1,
    $InventoryWindow/GridContainerBackground/Slot2,
    $InventoryWindow/GridContainerBackground/Slot3,
    $InventoryWindow/GridContainerBackground/Slot4,
    $InventoryWindow/GridContainerBackground/Slot5,
    $InventoryWindow/GridContainerBackground/Slot6,
    $InventoryWindow/GridContainerBackground/Slot7,
    $InventoryWindow/GridContainerBackground/Slot8
]

# Current items in each slot
var items: Array = []  # Array of ItemData or null

func _ready():
    # Initialize empty inventory
    items.resize(slots.size())
    for i in range(slots.size()):
        items[i] = null
        setup_slot_interaction(i)

    # Populate with demo items
    populate_demo_items()

func setup_slot_interaction(slot_index: int):
    var slot = slots[slot_index]
    slot.mouse_filter = Control.MOUSE_FILTER_STOP
    slot.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot_index))
    slot.modulate = Color(1, 1, 1, 0.3)  # Show empty slot visually

func _on_slot_gui_input(event: InputEvent, slot_index: int):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if items[slot_index]:
            # Item clicked - show details or use
            print("Item clicked: %s (x%d)" % [items[slot_index].name, items[slot_index].current_count])
        else:
            # Empty slot clicked
            print("Empty slot %d clicked" % slot_index)

func populate_demo_items():
    # Add demo items to first 4 slots
    for i in range(min(4, slots.size())):
        if i < demo_items.size():
            add_item(demo_items[i], i)

func add_item(item: ItemData, slot_index: int) -> bool:
    if slot_index < 0 or slot_index >= slots.size():
        return false

    if items[slot_index] == null:
        items[slot_index] = item
        update_slot_display(slot_index)
        return true
    elif items[slot_index].id == item.id and items[slot_index].current_count < items[slot_index].stack_size:
        # Stack with existing item
        items[slot_index].current_count += 1
        update_slot_display(slot_index)
        return true
    return false

func remove_item(slot_index: int) -> ItemData:
    if slot_index < 0 or slot_index >= slots.size():
        return null

    var item = items[slot_index]
    items[slot_index] = null
    update_slot_display(slot_index)
    return item

func update_slot_display(slot_index: int):
    var slot = slots[slot_index]
    var item = items[slot_index]

    # Clear slot first
    for child in slot.get_children():
        child.queue_free()

    if item:
        slot.modulate = Color(1, 1, 1, 1)  # Full opacity when has item

        # Add item icon (colored square)
        var icon = ColorRect.new()
        icon.color = item.color
        icon.size = Vector2(48, 48)
        icon.position = Vector2((slot.size.x - 48) / 2, (slot.size.y - 48) / 2)
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(icon)

        # Add name label
        var name_label = Label.new()
        name_label.text = item.name
        name_label.add_theme_font_size_override("font_size", 10)
        name_label.add_theme_color_override("font_color", Color(1, 1, 1))
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.anchor_left = 0
        name_label.anchor_right = 1
        name_label.anchor_top = 1
        name_label.anchor_bottom = 1
        name_label.offset_top = -14
        name_label.offset_bottom = -2
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(name_label)

        # Add count overlay if stacked
        if item.current_count > 1:
            var count_label = Label.new()
            count_label.text = "x%d" % item.current_count
            count_label.add_theme_font_size_override("font_size", 11)
            count_label.add_theme_color_override("font_color", Color(1, 1, 1))
            count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
            count_label.anchor_right = 1
            count_label.anchor_bottom = 1
            count_label.offset_right = -4
            count_label.offset_bottom = -4
            count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            slot.add_child(count_label)
    else:
        slot.modulate = Color(1, 1, 1, 0.3)  # Dim when empty

# Public API to add items from other scripts
func add_item_by_id(item_id: int, slot_index: int = -1) -> bool:
    for item in demo_items:
        if item.id == item_id:
            if slot_index == -1:
                # Find empty slot
                for i in range(items.size()):
                    if items[i] == null:
                        return add_item(item, i)
                return false
            else:
                return add_item(item, slot_index)
    return false
