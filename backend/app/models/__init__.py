"""
Import every model here so Alembic's autogenerate (and Base.metadata.create_all)
can see all tables. Add new model modules to this list as they're created.
"""
from app.models.user import User, FarmerProfile, UserRole          # noqa: F401
from app.models.farm import Farm, WaterAvailability                # noqa: F401
from app.models.crop import Crop, CropHistoryEntry, CropStatus     # noqa: F401
from app.models.disease import DiseaseDetectionRecord               # noqa: F401
from app.models.pest import PestDetectionRecord                     # noqa: F401
from app.models.feedback import FarmerFeedback, FeedbackType        # noqa: F401

# Module 2 (Marketplace)
from app.models.product import (                                    # noqa: F401
    Category, Listing, ListingImage, Inquiry, ListingType, ListingStatus,
)
from app.models.supplier import SupplierProductType                 # noqa: F401
from app.models.order import Order, Review, OrderStatus            # noqa: F401

# Module 3 (Communication + Community)
from app.models.chat import Conversation, Message                  # noqa: F401
from app.models.community import Post, Comment, PostLike, PostCategory  # noqa: F401
from app.models.issue_report import (                               # noqa: F401
    IssueReport, ReportTargetType, ReportReason, ReportStatus,
)
