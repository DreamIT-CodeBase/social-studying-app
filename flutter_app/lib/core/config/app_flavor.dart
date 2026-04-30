enum AppFlavor { admin, student }

AppFlavor _currentFlavor = AppFlavor.student;

AppFlavor get currentFlavor => _currentFlavor;

void setAppFlavor(AppFlavor flavor) => _currentFlavor = flavor;
